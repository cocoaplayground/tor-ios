//
//  TORThread.m
//  Tor
//
//  Created by Conrad Kramer on 7/19/15.
//  Copyright © 2015 Kramer Software Productions, LLC. All rights reserved.
//

#include <or/or.h>
#include <or/main.h>

#import "TORThread.h"

static TORThread *_thread = nil;

@implementation TORThread {
    NSArray *_arguments;
}

+ (instancetype)torThread {
    return _thread;
}

- (instancetype)init {
    return [self initWithArguments:nil];
}

- (instancetype)initWithArguments:(NSArray *)arguments {
    NSAssert(_thread == nil, @"There can only be one TORThread per process");
    self = [super init];
    if (self) {
        _thread = self;
        _arguments = arguments;
        
        self.name = @"Tor";
    }
    return self;
}

- (void)main {
    int argc = (int)_arguments.count;
    char *argv[argc + 2];
    argv[0] = "tor";
    for (NSUInteger idx = 1; idx < argc; idx++)
        argv[idx] = (char *)[_arguments[idx] UTF8String];
    argv[argc] = NULL;
    
    tor_main(argc, argv);
}

@end
