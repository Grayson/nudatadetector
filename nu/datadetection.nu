;; @discussion Data detection stuff for NSTextViews.
;;
;; @copyright  Copyright (c) 2008 Grayson Hansard, From Concentrate Software

(load "datadetector")
;; @abstract Storage for data detected in an NSTextView that also provides accurate mouse tracking in the view.
;; @discussion The DataDetectionController is the behind-the-scenes wizard.  It uses the NuDataDetector to find
;; potential data objects and then creates NSTrackingAreas for the associated text view.  Whenever a user mouses
;; over a data point, the DataDetectionController displays a button.  The entire mechanism is based on delegation
;; methods.  In order ot use effectively, set your text view delegate and make sure that it responds to
;; <code>textView:createdDataDetectionController:</code> and <code>textView:menuForData:</code>.
;;
;; <code>textView:createdDataDetectionController:</code> alerts the delegate to when the the DataDetectionController
;; is created.  Your delegate should catch the DataDetectionController for memory management purposes.
;;
;; <code>textView:menuForData:</code> is called when a user clicks on a button.  You should return a menu describing
;; the options available for the data.
(class DataDetectionController is NSObject
	(ivars)
	(- (id) init is
		(set self (super init))
		(set @trackingAreas nil)
		(set @buttonTrackingArea nil)
		(set @view nil)
		(set @button ((NSButton alloc) initWithFrame:'(0 0 16 16)))
		(@button setTarget:self)
		(@button setAction:"buttonPressed:")
		(@button setHidden:YES)
		self)
		
	(- (void) setView:(id) view is
		((NSNotificationCenter defaultCenter) removeObserver:self name:"NSViewFrameDidChangeNotification" object:@view)
		(set @view view)
		((NSNotificationCenter defaultCenter) addObserver:self selector:"viewFrameHasChanged:" name:"NSViewFrameDidChangeNotification" object:@view)
		(if (@button superview) (@button removeFromSuperview))
		(@view addSubview:@button))
	
	(- (id) trackingAreas is (@trackingAreas))
	(- (void) setTrackingAreasForData:(id) data is
		(set lm (@view layoutManager))
		(set tc (@view textContainer))
		
		(if (@trackingAreas) (@trackingAreas each:(do (ta) 
			(@view removeTrackingArea:ta) )) )
		(set @trackingAreas (NSMutableArray array))
		(data each:(do (datum)
			(set range ((datum objectForKey:"range") rangeValue))
			(set rect (lm boundingRectForGlyphRange:range inTextContainer:tc))
			(set ta ((NSTrackingArea alloc) initWithRect:rect options:(+ 1 16) owner:self userInfo:(dict "rect" (NSValue valueWithRect:rect) "info" datum)))
			(@trackingAreas addObject:ta)
			(@view addTrackingArea:ta) )) )
	
	(- (void) viewFrameHasChanged:(id) sender is 
		(self setTrackingAreasForData:(self data)) )

	(- (void) dealloc is
		((NSNotificationCenter defaultCenter) removeObserver:self)
		
		(@trackingAreas each:(do (ta) (@view removeTrackingArea:ta)))
		(@view updateTrackingAreas)
		; (@trackingAreas release) ; Releasing the @trackingAreas causes a SIGSEGV
		
		(if (@buttonTrackingArea)
			(@view removeTrackingArea:@buttonTrackingArea)
			(@buttonTrackingArea release) )
		
		(if (@button superview) (@button removeFromSuperview))
		; (@button release) ; Releasing the @button causes a SIGSEGV
		; (super dealloc) ; Calling (super dealloc) causes a SIGSEGV
		)
		
	(- (void) mouseEntered:(id) event is
		(if (event userData) ; Don't do anything special if this is the button's tracking area
			(set userData ((event userData) object))
			(set rect ((userData objectForKey:"rect") rectValue))
			(set x (+ (rect first) (rect third)))
			(set y (rect second))
			(@button setFrame:(list x y 14 14))
			(@button setHidden:NO)
			; Set up a tracking area so that the button doesn't disappear if we mouse over it
			(set @buttonTrackingArea ((NSTrackingArea alloc) initWithRect:(@button frame) options:(+ 1 16) owner:self userInfo:nil))
			(@view addTrackingArea:@buttonTrackingArea))
		)
	(- (void) mouseExited:(id) event is
		(if (not (@button hitTest:(@view convertPoint:(event locationInWindow) fromView:nil)))
			(@button setHidden:YES)
			(@view removeTrackingArea:@buttonTrackingArea)))
	
	(- (void) buttonPressed:(id) sender is
		(function pointIsInRect (p r)
			(set truth YES)
			(if (< (p first) (r first)) (set truth NO))
			(if (> (p first) (+ (r first) (r third))) (set truth NO))
			(if (< (p second) (r second)) (set truth NO))
			(if (> (p second) (+ (r second) (r fourth))) (set truth NO))
			truth)
		(set bf (@button frame))
		(set point (list (- (bf first) 1) (bf second)) )
		
		(set tas (@trackingAreas select:(do (ta)
			(set info (ta userInfo))
			(set rect ((info objectForKey:"rect") rectValue))
			(if (pointIsInRect point rect) t
			(else nil)) )) )
		
		(set datum (((tas lastObject) userInfo) objectForKey:"info"))
		(if (and datum ((@view delegate) respondsToSelector:"textView:menuForData:"))
			(set menu ((@view delegate) textView:self menuForData:datum))
			(if (menu) (NSMenu popUpContextMenu:menu withEvent:((NSApplication sharedApplication) currentEvent) forView:@button) ) ) )
	
	;; Returns all of the data points as an array of dictionaries.  Each dictionary should contain at least
	;; an <code>object</code> key, a <code>range</code> key (as an NSValue) representing location of the found
	;; data in the textview, and a <code>type</code> key.  There may be other keys dependent on type.
	(imethod (id) data is
		(@trackingAreas valueForKeyPath:"userInfo.info"))
	
	;; Filters all of the found data to be of one type.  For instance, if you wanted to find all of the urls
	;; in the document, you'd use <code>[ddc dataOfType:@"url"];</code>.
	(imethod (id) dataOfType:(id) type is
		((self data) select:(do (datum) (== (datum objectForKey:"type") type) )) )
)

(class NSTextView
	;; Scrub the <code>string</code> of the text view for data.  This uses a delegate method.
	;; The text view's delegate should respond to <code>textView:createdDataDetectionController:</code> and
	;; <code>textView:menuForData:</code>.
	;;
	;; Note that you are responsible for memory management of the DataDetectionController so catch it in 
	;; <code>textView:createdDataDetectionController:</code>.
	(imethod (void) detectData:(id) sender is
		(set ddc ((DataDetectionController new) autorelease))
		(ddc setView:self)
		(ddc setTrackingAreasForData:((self string) detectedData))
		
		(if ((self delegate) respondsToSelector:"textView:createdDataDetectionController:")
			((self delegate) textView:self createdDataDetectionController:ddc))
	)
)
