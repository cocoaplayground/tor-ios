//
//  TORController.h
//  Tor
//
//  Created by Conrad Kramer on 5/10/14.
//  Copyright (c) 2014 Kramer Software Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TORController : NSObject

@property (nonatomic, readonly, getter=isConnected) BOOL connected;

- (instancetype)initWithDataDirectory:(NSString *)dataDirectory NS_DESIGNATED_INITIALIZER;

- (BOOL)connect;

- (id)addObserverForCircuitEstablished:(void (^)(BOOL established))block;
- (id)addObserverForStatusEvents:(BOOL (^)(NSString *type, NSString *severity, NSString *action, NSDictionary *arguments))block;

- (void)removeObserver:(id)observer;

@end
