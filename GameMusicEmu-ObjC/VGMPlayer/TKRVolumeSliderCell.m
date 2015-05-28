//
//  TKRVolumeSliderCell.m
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 3/27/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import "TKRVolumeSliderCell.h"

@implementation TKRVolumeSliderCell

- (CGFloat)knobThickness {
	//NSLog(@"Knob thickness is %f", [super knobThickness]);
	return [super knobThickness];
}

- (void)drawKnob:(NSRect)knobRect {
	[super drawKnob:knobRect];
	//NSLog(@"Draw knob at (%f, %f) with height %f and width %f", knobRect.origin.x, knobRect.origin.y, knobRect.size.height, knobRect.size.width);
}

@end
