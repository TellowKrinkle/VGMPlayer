//
//  Document.h
//  VGMPlayer
//
//  Created by Evan Tang on 3/26/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VGMPlayerWindow.h"

@interface Document : NSDocument

@property (nonatomic, readonly) NSURL *prevFile;
@property (nonatomic, readonly) NSURL *nextFile;
@property (weak) IBOutlet NSButton *playPauseButton;
@property (weak) IBOutlet NSButton *prevButton;
@property (weak) IBOutlet NSButton *nextButton;
@property (weak) IBOutlet NSSlider *playhead;
@property (weak) IBOutlet NSTextField *leftTimeIndicator;
@property (weak) IBOutlet NSTextField *rightTimeIndicator;
@property (weak) IBOutlet VGMPlayerWindow *playerWindow;


- (NSString *)formatTime:(long)samples;
- (IBAction)playPause:(id)sender;
- (IBAction)goNext:(id)sender;
- (IBAction)goPrevious:(id)sender;
- (IBAction)changeVolume:(id)sender;

@end

