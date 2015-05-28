//
//  Document.h
//  VGMPlayer
//
//  Created by Evan Tang on 3/26/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Document : NSDocument

@property (nonatomic, copy) NSURL *file;
@property (weak) IBOutlet NSButton *playPauseButton;
@property (weak) IBOutlet NSSlider *playhead;
@property (weak) IBOutlet NSTextField *leftTimeIndicator;
@property (weak) IBOutlet NSTextField *rightTimeIndicator;

- (NSString *)formatTime:(long)samples;
- (IBAction)playPause:(id)sender;
- (IBAction)changeVolume:(id)sender;

@end

