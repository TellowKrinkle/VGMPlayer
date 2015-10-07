//
//  VioGSF.h
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 9/3/15.
//  Copyright © 2015 TellowKrinkle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GameMusicDataSource.h"

@interface VioGSF : NSObject <GameMusicDataSource>

@property (nonatomic, readonly) int sampleRate;
@property (nonatomic) long position;
@property (nonatomic, readonly) long trackLength;
@property (nonatomic, readonly) NSDictionary *tags;

@end
