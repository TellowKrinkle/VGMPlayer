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
	if (theEvent.keyCode == 49) {
		[(Document *)self.delegate playPause:self];
	}
	else {
		[super keyDown:theEvent];
	}
}

@end
