//
//  VioGSF.m
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 9/3/15.
//  Copyright © 2015 TellowKrinkle. All rights reserved.
//

#import "VioGSF.h"
#include "PSFLib/PSFLib/psflib.h"
//#include "VioG

#pragma mark PSFLib callbacks

static void * psf_file_fopen(const char *url) {
	return fopen(url, "r");
}

static size_t psf_file_fread(void *buffer, size_t size, size_t count, void *handle) {
	return fread(buffer, size, count, handle);
}

static int psf_file_fseek(void *handle, int64_t offset, int whence) {
	return fseek(handle, offset, whence);
}

static int psf_file_fclose(void *handle) {
	return fclose(handle);
}

static long psf_file_ftell(void *handle) {
	return ftell(handle);
}

static psf_file_callbacks psfFileSystem = {
	"/:",
	psf_file_fopen,
	psf_file_fread,
	psf_file_fseek,
	psf_file_fclose,
	psf_file_ftell
};

@implementation VioGSF

@end
