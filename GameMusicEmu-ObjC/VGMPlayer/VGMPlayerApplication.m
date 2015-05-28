//
//  VGMPlayerApplication.m
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 5/24/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import "VGMPlayerApplication.h"
#import "Document.h"

@implementation VGMPlayerApplication

- (void)sendEvent:(NSEvent *)event
{
	// Catch media key events
	if ([event type] == NSSystemDefined && [event subtype] == 8)
	{
		if (self.windows.count > 0) {
			int keyCode = (([event data1] & 0xFFFF0000) >> 16);
			int keyFlags = ([event data1] & 0x0000FFFF);
			int keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA;
			
			// Process the media key event and return
			[self mediaKeyEvent:keyCode state:keyState optionKeyHeld:(event.modifierFlags & NSAlternateKeyMask) > 0];
			return;
		}
	}
	// Continue on to super
	[super sendEvent:event];
}

- (void)mediaKeyEvent:(int)key state:(BOOL)state optionKeyHeld:(bool)option
{
	switch (key)
	{
			// Play pressed
		case NX_KEYTYPE_PLAY:
			if (state == NO) {
				if (option) {
					for (Document *document in self.orderedDocuments) {
						[document playPause:self];
					}
				}
				else {
					[(Document *)self.orderedDocuments[0] playPause:self];
				}
			}
			break;
			
			// Next
		case NX_KEYTYPE_FAST:
//			if (state == YES)
//				[(AppDelegate *)[self delegate] seekForward:self];
			break;
			
			// Previous
		case NX_KEYTYPE_REWIND:
//			if (state == YES)
//				[(AppDelegate *)[self delegate] seekBack:self];
			break;
	}
}

@end
