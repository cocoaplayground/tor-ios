//
//  TORThread.h
//  Tor
//
//  Created by Conrad Kramer on 7/19/15.
//
//

#import <Foundation/Foundation.h>

@interface TORThread : NSThread

+ (instancetype)torThread;

- (instancetype)initWithDataDirectory:(NSString *)dataDirectory socksSocketPath:(NSString *)socksSocketPath controlSocketPath:(NSString *)controlSocketPath arguments:(NSArray *)arguments;
- (instancetype)initWithArguments:(NSArray *)arguments NS_DESIGNATED_INITIALIZER;

@end
