//
//  Controller.h
//  NuDataDetector
//
//  Created by Grayson Hansard on 3/21/08.
//  Copyright 2008 From Concentrate Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface Controller : NSObject {
	IBOutlet NSTextView *textView;
	id _dataDetectedController;
}

@property (retain) id dataDetectedController;

@end
