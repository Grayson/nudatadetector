;; @file       menu.nu
;; @discussion An example showing Cocoa menu generation with Nu.
;;
;; @copyright  Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.

;; @function build-menu
;; build an application's menus from a specified description (see example below)
(function build-menu (menu-description appname)
     (cond
          ((eq (car menu-description) 'menu)
           (set menu ((NSMenu alloc) initWithTitle:(eval (car (cdr menu-description)))))
           (cond ((eq (menu title) "Main")     ((NSApplication sharedApplication) setMainMenu:menu))
                 ((eq (menu title) "Window")   ((NSApplication sharedApplication) setWindowsMenu:menu))
                 ((eq (menu title) "Services") ((NSApplication sharedApplication) setServicesMenu:menu))
                 ((eq (menu title) "Application") (menu setTitle:"\uf8ff"))
                 ;; The above value is an Apple-specific constant that marks the Application Menu
                 ;; http://lists.apple.com/archives/cocoa-dev/2006/Sep/msg00011.html
                 (else nil))
           (set rest (cdr (cdr menu-description)))
           (if rest (rest each:(do (item) (menu addItem:(build-menu item appname)))))
           (set item ((NSMenuItem alloc) initWithTitle:(eval (car (cdr menu-description))) action:nil keyEquivalent:""))
           (item setSubmenu:menu)
           item)
          ((eq (car menu-description) 'separator)
           (NSMenuItem separatorItem))
          (t
            (let ((item ((NSMenuItem alloc) initWithTitle:(eval (car menu-description)) action:nil keyEquivalent:""))
                  (rest (cdr menu-description)))
                 (if rest
                     (rest eachPair:
                           (do (key value)
                               (cond ((eq key 'action:)      (item setAction:(eval value)))
                                     ((eq key 'key:)         (item setKeyEquivalent:(eval value)))
                                     ((eq key 'modifier:)    (item setKeyEquivalentModifierMask:(eval value)))
                                     ((eq key 'target:)      (item setTarget:(eval value)))
                                     ((eq key 'tag:)         (item setTag:(eval value)))
                                     (else                   nil)))))
                 
                 item))))

;; default menu description
(set default-application-menu
     '(menu "Main"
            (menu "Application"
                  ("About #{appname}" action:"orderFrontStandardAboutPanel:")
                  ("Preferences..." key:",")
                  (separator)
                  (menu "Services")
                  (separator)
                  ("Hide #{appname}" action:"hide:" key:"h")
                  ("Hide Others" action:"hideOtherApplications:" key:"h" modifier:(+ NSAlternateKeyMask NSCommandKeyMask))
                  ("Show All" action:"unhideAllApplications:")
                  (separator)
                  ("Quit #{appname}" action:"terminate:" key:"q"))
            (menu "File"
                  ("New")
                  ("Open..." key:"o")
                  (menu "Open Recent"
                        ("Clear Menu" action:"clearRecentDocuments:"))
                  (separator)
                  ("Close" action:"performClose:" key:"w")
                  ("Save" key:"s")
                  ("Save as..." key:"S")
                  ("Revert")
                  (separator)
                  ("Page Setup..." action:"runPageLayout:" key:"P")
                  ("Print..." action:"print:" key:"p"))
            (menu "Edit"
                  ("Undo" action:"undo:" key:"z")
                  ("Redo" action:"redo:" key:"Z")
                  (separator)
                  ("Cut" action:"cut:" key:"x")
                  ("Copy" action:"copy:" key:"c")
                  ("Paste" action:"paste:" key:"v")
                  ("Delete" action:"delete:")
                  ("Select All" action:"selectAll:" key:"a")
                  (separator)
                  (menu "Find"
                        ("Find..." key:"f")
                        ("Find Next" key:"g")
                        ("Find Previous" key:"d")
                        ("Use Selection for Find" key:"e")
                        ("Scroll to Selection" key:"j"))
                  (menu "Spelling"
                        ("Spelling..." action:"showGuessPanel:")
                        ("Check Spelling" action:"checkSpelling:")
                        ("Check Spelling as You Type" action:"toggleContinuousSpellChecking:")))
            (menu "Window"
                  ("Minimize" action:"performMiniaturize:" key:"m")
                  (separator)
                  ("Bring All to Front" action:"arrangeInFront:"))
            (menu "Help"
                  ("#{appname} Help" action:"showHelp:" key:"?"))))
