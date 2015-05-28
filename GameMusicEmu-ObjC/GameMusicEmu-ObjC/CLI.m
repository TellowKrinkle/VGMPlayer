//
//  main.m
//  GameMusicEmu-ObjCTest
//
//  Created by Evan Tang on 3/10/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TKRPlayer.h"

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		TKRPlayer *player = [[TKRPlayer alloc] init];
		if (argc < 2) {
			NSLog(@"Usage: fileToPlay [trackNo]");
			return 1;
		}
		else if (argc == 2) {
			[player openFile:[NSURL fileURLWithFileSystemRepresentation:argv[1] isDirectory:false relativeToURL:nil] error:nil];
			[player play];
		}
		else {
			[player openFile:[NSURL fileURLWithFileSystemRepresentation:argv[1] isDirectory:false relativeToURL:nil] withTrackNo:atoi(argv[2]) error:nil];
			[player play];
		}
		
		do {
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
		} while (![player isStopped]);
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2, false);
	}
}