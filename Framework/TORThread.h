//
//  TORThread.h
//  Tor
//
//  Created by Conrad Kramer on 7/19/15.
//  Copyright © 2015 Kramer Software Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TORThread : NSThread

+ (instancetype)torThread;

- (instancetype)initWithArguments:(NSArray *)arguments NS_DESIGNATED_INITIALIZER;

@end
