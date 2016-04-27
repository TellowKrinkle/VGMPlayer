//
//  VGMPlayerWindow.m
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 5/24/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import "VGMPlayerWindow.h"
#import "Document.h"

@implementation VGMPlayerWindow

- (void)keyDown:(NSEvent *)theEvent {
	switch (theEvent.keyCode) {
		case 49: // Space Key
			[(Document *)self.delegate playPause:self];
			break;
		case 29: // 0 Key
			[(Document *)self.delegate setSpeed:0.5];
			break;
		case 18: // 1 Key
			[(Document *)self.delegate setSpeed:1.0];
			break;
		case 19: // 2 Key
			[(Document *)self.delegate setSpeed:2.0];
			break;
		default:
			[super keyDown:theEvent];
			break;
	}
}

@end
