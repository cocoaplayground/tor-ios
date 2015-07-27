//
//  TORController.h
//  Tor
//
//  Created by Conrad Kramer on 5/10/14.
//  Copyright (c) 2014 Kramer Software Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TORController : NSObject

+ (instancetype)sharedController;

@property (readonly, nonatomic) NSString *socksSocketPath;

@property (readonly, nonatomic) BOOL circuitEstablished;

@end
