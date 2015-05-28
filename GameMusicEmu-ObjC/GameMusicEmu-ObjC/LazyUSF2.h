//
//  LazyUSFWrapper.h
//  GameMusicEmu-ObjCTest
//
//  Created by Evan Tang on 3/22/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GameMusicDataSource.h"

@interface LazyUSF2 : NSObject <GameMusicDataSource>

@property (nonatomic, readonly) int sampleRate;
@property (nonatomic) long position;
@property (nonatomic, readonly) long trackLength;

- (instancetype)initWithSampleRate:(int)sampleRate;

@end
