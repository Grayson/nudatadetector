//
//  Controller.m
//  NuDataDetector
//
//  Created by Grayson Hansard on 3/21/08.
//  Copyright 2008 From Concentrate Software. All rights reserved.
//

#import "Controller.h"
#import <Nu/Nu.h>

@implementation Controller
@synthesize dataDetectedController=_dataDetectedController;

+ (void)initialize
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	// The following creates the Nu parser and loads the datadetection script.
	// We're doing this in initialize because we need to add the `detectData:` method to NSTextView
	// before it loads from the nib.  Since it is defined in the script, we load now.
	id nu = [Nu parser];
	[nu eval:[nu parse:[NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"datadetection" ofType:@"nu"]]]];
	[nu close];	
	
	[pool release];
}

- (void)textView:(NSTextView *)tv createdDataDetectionController:(id)ddc
{
	// This delegate method is called by the text view when it creates the controller.
	// You are responsible for memory management here.  If you don't catch it, it will leak.
	if (self.dataDetectedController) [self.dataDetectedController release];		
	self.dataDetectedController = [ddc autorelease];
	
	// As a convenience for this example, the data that is detected will be colored blue.
	NSLayoutManager *lm = [textView layoutManager];
	for (NSDictionary *datum in (NSArray *)[ddc data]) {
		NSRange range = [[datum objectForKey:@"range"] rangeValue];
		[lm addTemporaryAttributes:[NSDictionary dictionaryWithObject:[NSColor blueColor] forKey:NSForegroundColorAttributeName] forCharacterRange:range];		
	}
}

- (NSMenu *)textView:(NSTextView *)tv menuForData:(NSDictionary *)data
{
	// This is called whenever the data detectino button is clicked.  You should build an NSMenu and return it based on
	// what you want to do.  Here, I'm simply catching for email and url types.
	NSString *type = [data objectForKey:@"type"];
	
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"dataMenu"];
	if ([type isEqualToString:@"email"])
	{
		NSMenuItem *mi = [menu addItemWithTitle:[NSString stringWithFormat:@"Email %@", [data objectForKey:@"object"]] action:@selector(openUrl:) keyEquivalent:@""];
		[mi setTarget:self];
		[mi setRepresentedObject:[NSString stringWithFormat:@"mailto:%@", [data objectForKey:@"object"]]];
	}
	else if ([type isEqualToString:@"url"])
	{
		NSMenuItem *mi = [menu addItemWithTitle:[NSString stringWithFormat:@"Open %@", [data objectForKey:@"object"]] action:@selector(openUrl:) keyEquivalent:@""];
		[mi setTarget:self];
		[mi setRepresentedObject:[data objectForKey:@"object"]];
		
	}
	else
	{
		[menu addItemWithTitle:[NSString stringWithFormat:@"Object of type: \"%@\"; value: %@", type, [data objectForKey:@"object"]] action:@selector(openUrl:) keyEquivalent:@""];
	}
	return [menu autorelease];
}

- (void)openUrl:(NSMenuItem *)sender
{
	// For simplicity sake, both emails and urls directed here
	NSString *tmp = [sender representedObject];
	NSURL *url = [NSURL URLWithString:tmp];
	if (url) [[NSWorkspace sharedWorkspace] openURL:url];
}

@end
