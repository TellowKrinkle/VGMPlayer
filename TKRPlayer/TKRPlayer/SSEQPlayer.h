//
//  SSEQPlayer.h
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 9/18/15.
//  Copyright © 2015 TellowKrinkle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GameMusicDataSource.h"

@interface SSEQPlayer : NSObject <GameMusicDataSource>

@property (nonatomic, readonly) int sampleRate;
@property (nonatomic) long position;
@property (nonatomic, readonly) long trackLength;
@property (nonatomic, readonly) NSDictionary *tags;

- (instancetype)initWithSampleRate:(int)sampleRate NS_DESIGNATED_INITIALIZER;

@end
