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

@implementation TORThread {
    NSArray *_arguments;
}

- (instancetype)init {
    return [self initWithArguments:nil];
}

- (instancetype)initWithArguments:(NSArray *)arguments {
    NSParameterAssert(arguments);
    self = [super init];
    if (self) {
        _arguments = arguments;
    }
    return self;
}

- (void)main {
    int argc = (int)_arguments.count;
    char *argv[argc + 2];
    argv[0] = "tor";
    for (NSUInteger idx = 1; idx < argc + 1; idx++)
        argv[idx] = (char *)[_arguments[idx] UTF8String];
    argv[argc] = NULL;
    
    tor_main(argc, argv);
}

@end
