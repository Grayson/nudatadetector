;; @file       datadetector.nu
;; @discussion Finds data in NSStrings similar to Apple's Data Detectors.  Intended for use in conjunction 
;; with datadetection.nu.
;;
;; @copyright  Copyright (c) 2008 Grayson Hansard, From Concentrate Software.

'() ; nudoc thinks the above comments are part of NSString unless there's another object in the way.

(class NSString
	;; Convenience method to get data from an NSString.
	(cmethod (id) detectedData is (NuDataDetector dataDetectedInString:self)))

;; @abstract Finds data in strings based on regex patterns.
;; @discussion The NuDataDetector is a shell class.  All of its functionality is implemented from class methods, not instance methods.
;; There's no intneral plumbing so there's not much point in doing it different.  It was originally a collection of
;; Nu functions.  However, implementing it as a class offers more flexibility.  For instance, if you want to add more
;; data detectors in a personal project or something, you can simply create a category and add class methods. The
;; NuDataDetector will run any class method that begins with "detect".  Each detection method should return an NSArray
;; of NSDictionaries that describe the detected data.  Each dictionary should have a key called "range" that represents
;; the location of the detected data in the string as an NSValue, a key called "type" that identifies what type of data
;; was detected, and a key called "object" with represents the data as transformed into another data type (for instance,
;; dates are converted into NSCalendarDates).  If you want to turn off a particular detector, you can redefine it in a 
;; category to return <code>nil</code>.
(class NuDataDetector is NSObject
	;; This is the main entrance point to the data detector.  It takes an <code>NSString</code> and returns an array
	;; of dictionaries.  See the class description for more information.
	;;
	;; This method works by iterating through all of NuDataDetector's class methods and calling every method that
	;; begins with "detect".  You can therefore extend NuDataDetector by creating a category with more class methods
	;; beginning with "detect".
	(cmethod (id) dataDetectedInString:(id)string is
		(set arr (NSMutableArray array))
		((self classMethods) each:(do (method)
			(if ((method name) hasPrefix:"detect") 
				(arr addObjectsFromArray:(self performSelector:(method name) withObject:string)) )))
		arr)

	(function convertComponentsIntoCalendarDate (month day year)
		(if (month isKindOfClass:(NSNumber class))
			(if (> (year length) 2) (NSCalendarDate dateWithString:"#{month} #{day} #{year}" calendarFormat:"%m %d %Y")
			(else (NSCalendarDate dateWithString:"#{month} #{day} #{year}" calendarFormat:"%m %d %y")))
		(else
			(if (> (year length) 2) (NSCalendarDate dateWithString:"#{month} #{day} #{year}" calendarFormat:"%b %d %Y")
			(else (NSCalendarDate dateWithString:"#{month} #{day} #{year}" calendarFormat:"%b %d %y")) )) ) )

	(+ (id) detectCalendarData:(id)txt is
		(set arr (NSMutableArray array))
		; Find text dates
		((/(\d+)? # $1 - Possible date preceding month name
		   [ \t]*
		   ([Jj]an|[Ff]eb|[Mm]a[ry]|[Jj]un|[Jj]ul|[Aa]ug|[Ss]ep|[Oo]ct|[Nn]ov|[Dd]ec) # $2 - Month name, $3
		   [\w]*
		   [ \t]*
		   (\d+)? # $4 - Possible date postceeding month name
		   [ \t]*,?[ \t]*
		   (\d{2,4})? # $5 - Year
		   /mx findAllInString:txt) each:(do (m)
				(set day 0)
				(set month 0)
				(set year 0)
				(if (m groupAtIndex:1) (set day (m groupAtIndex:1)))
				(set month (m groupAtIndex:2))
				(set tmp (m groupAtIndex:3))
				(if (and tmp (== day 0) (< (tmp length) 3) (< (tmp intValue) 32))
					(set day tmp)
				(else (set year tmp)))
				(set tmp (m groupAtIndex:4))
				(if (tmp) (set year tmp))
				(if (== year 0) (set year ((NSCalendarDate calendarDate) yearOfCommonEra)))
				(if (and day month year) (arr addObject:(dict "object" (convertComponentsIntoCalendarDate month day year) "range" (NSValue valueWithRange:(m range)) "type" "date")))
				))
		; Find numerical dates
		((/	(\d+)
			[ \t\/\-\.]+
			(\d+)
			[ \t\/\-\.]+
			(\d+)/mx findAllInString:txt) each:(do (m)
				(set day 0)
				(set month 0)
				(set year 0)
				(set tmp ((m groupAtIndex:1) intValue))
				(if (> tmp 12)
					(set day tmp)
					(set month ((m groupAtIndex:2) intValue))
				(else
					(set month tmp)
					(set day (m groupAtIndex:2))))
				(set year (m groupAtIndex:3))
				(arr addObject:(dict "object" (convertComponentsIntoCalendarDate month day year) "range" (NSValue valueWithRange:(m range)) "type" "date"))
		))
		arr)

	(+ (id) detectPersonalInfo:(id)txt is
		(set arr (NSMutableArray array))
		; Detect phone numbers
		(set cset (NSCharacterSet whitespaceAndNewlineCharacterSet))
		(( /(\+[ \t]?\d)? # $1 - Check if we have a "+" for an international number
			[ \t]*
			\(?
			(\d+) # $2
			[)-\/\. \t]+
			(\d+)
			[-\/\. \t]+
			(\d+)/mx findAllInString:txt) each:(do (m)
				(arr addObject:(dict "object" ((m group) stringByTrimmingCharactersInSet:cset) "range" (NSValue valueWithRange:(m range)) "type" "phone"))))
		; Detect addresses
		; Your guess is as good as mine
	
		; Detect name
		(load "AddressBook")
		(set ab (ABAddressBook sharedAddressBook))
		(set names ((ab people) map:(do (p) 
			(set first (p valueForProperty:"First"))
			(set last (p valueForProperty:"Last"))
			(set tmp nil)
			(if (and (!= first nil) (!= last nil))
				(set tmp (+ "(" first "[ \\t]*" last ")|(" last "[, \\t]*" first ")")) ) ; Having problems with string templating here.
			(if (tmp)
				(set m ((NuRegex regexWithPattern:tmp options:1) findInString:txt))
				(if (m)
					(dict "object" (dict "first" first "last" last) "abuid" (p uniqueId) "range" (NSValue valueWithRange:(m range)) "type" "name")))) ))
		(set names (names select:(do (tmp) tmp)))
		(if (== 1 (names count))
				(arr addObject:(names lastObject)))
		arr)

	(+ (id) detectInternetInfo:(id)txt is
		(set arr (NSMutableArray array))
		; Detect email addresses
		(( /(\S+@\S+\.\S{2,})/ findAllInString:txt) each:(do (m)
			(arr addObject:(dict "object" (m group) "range" (NSValue valueWithRange:(m range)) "type" "email"))))
		
		; Find urls
		((/\w+:\/{0,2}[-:@\w_~%=&#,\.\+\/]+/ findAllInString:txt) each:(do (m)
			(arr addObject:(dict "object" (m group) "range" (NSValue valueWithRange:(m range)) "type" "url")) ))
		arr)
)
