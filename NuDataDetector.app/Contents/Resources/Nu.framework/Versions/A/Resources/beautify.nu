;; @file       beautify.nu
;; @discussion Code beautification for Nu.
;;
;; @copyright  Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.

(global LPAREN '(')
(global RPAREN ')')
(global SPACE  ' ')
(global COLON  ':')
(global TAB    '\x09')

(class NSString
     ;; Create a copy of a string with leading and trailing whitespace removed.
     (imethod (id) strip is
          (self stringByTrimmingCharactersInSet:(NSCharacterSet whitespaceCharacterSet)))
     
     ;; Create a string consisting of the specified number of spaces.
     (cmethod (id) spaces: (id) count is
          (unless $spaces (set $spaces (NSMutableDictionary dictionary)))
          (unless (set spaces ($spaces objectForKey:count))
                  (set spaces "")
                  (set c count)
                  (unless c (set c 0))
                  (while (> c 0)
                         (spaces appendString:" ")
                         (set c (- c 1)))
                  ($spaces setObject:spaces forKey:count))
          (NSMutableString stringWithString:spaces)))

;; @abstract A Nu code beautifier.
;; @discussion This class is used by nubile, the standalone Nu code beautifier, to automatically indent Nu code.
(class NuBeautifier is NSObject
     (ivars)
     
     ;; Beautify a string containing Nu source code.  The method returns a string containing the beautified code.
     (imethod (id) beautify:(id) text is
          (set result "")
          
          (set indentation_stack ((NuStack alloc) init))
          (indentation_stack push:0)
          
          (set pattern /\(def|\(macro|\(function|\(class|\(imethod|\(cmethod/)
          
          (set nube-parser ((NuParser alloc) init))
          (set @olddepth 0)
          
          (set lines (text componentsSeparatedByString:"\n"))
          (lines eachWithIndex:
                 (do (input-line line-number)
                     ;; indent line to current level of indentation
                     (if (or (eq (nube-parser state) 3) ;; parsing a herestring
                             (eq (nube-parser state) 4)) ;; parsing a regex
                         (then (set line input-line))
                         (else (set line (NSString spaces:(indentation_stack top)))
                               (line appendString:(input-line strip))))
                     (if (eq line-number (- (lines count) 1))
                         (then (result appendString: line))
                         (else (result appendString: line) (result appendString:"\n")))
                     
                     (try
                         (nube-parser parse:line)
                         (catch (exception)
                                (result appendString: ";; ")
                                (result appendString: (exception name))
                                (result appendString: ": ")
                                (result appendString: (exception reason))
                                (result appendString: "\n")))
                     (nube-parser newline)
                     
                     ;; account for any changes in indentation
                     (set indentation_change (- (nube-parser parens) @olddepth))
                     (set @olddepth (nube-parser parens))
                     (cond ((> indentation_change 0)
                            ;; Going down, compute new levels of indentation, beginning with each unmatched paren.
                            (set positions ((NSMutableArray alloc) init))
                            (set i (- ((nube-parser opens) depth) indentation_change))
                            (while (< i ((nube-parser opens) depth))
                                   (positions addObject:((nube-parser opens) objectAtIndex:i))
                                   (set i (+ i 1)))
                            ;; For each unmatched paren, find a good place to indent with respect to it.
                            ;; Push that on the indentation stack.
                            (positions each:
                                 (do (p)
                                     (if (pattern findInString:line)
                                         (then
                                              (indentation_stack push:(+ p 4))) ;; set to 2 for aggressively tight formatting
                                         (else
                                              (set j p)
                                              (set finished nil)
                                              (while (and (< j (line length))
                                                          (not finished))
                                                     (case (line characterAtIndex:j)
                                                           (SPACE  (while (and (< j (line length)) (eq (line characterAtIndex:j) SPACE)) (set j (+ j 1)))
                                                                   (if (> j (+ p 8)) (set j (+ p 4)))
                                                                   ;;(if (> j (+ p 2)) (set j (+ p 2))) ;; aggressively tight formatting
                                                                   (indentation_stack push:j)
                                                                   (set finished t))
                                                           (LPAREN (indentation_stack push:j)
                                                                   (set finished t))
                                                           (COLON  ;; we're starting with a label. indent at the last paren
                                                                   (indentation_stack push:p)
                                                                   (set finished t))
                                                           (else   (set j (+ j 1)))))
                                              (if (and (eq j (line length)) (not finished))
                                                  (indentation_stack push:j)))))))
                           ((< indentation_change 0)
                            ;; Going up, pop indentation positions off the stack.
                            ((- 0 indentation_change) times:
                             (do (i) (indentation_stack pop))))
                           (else nil))))
          result))