//
//  TorController.m
//  Tor
//
//  Created by Conrad Kramer on 5/10/14.
//  Copyright (c) 2014 Kramer Software Productions, LLC. All rights reserved.
//

#include <or/or.h>

#import "TORController.h"
#import "TORThread.h"

const char tor_git_revision[] =
#ifndef _MSC_VER
#include "micro-revision.i"
#endif
"";

@interface TORController ()

@property (readwrite, nonatomic) BOOL circuitEstablished;

@end

static TORController *sharedController = nil;

@implementation TORController {
    TORThread *_thread;
    NSString *_dataDirectory;
    NSInteger _controlPort;
    dispatch_io_t _channel;
}

+ (instancetype)sharedController {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[self alloc] init];
    });
    return sharedController;
}

- (instancetype)init {
    NSAssert(sharedController == nil, @"There can only be one TORController per process");
    self = [super init];
    if (self) {
        _dataDirectory = NSTemporaryDirectory();
        _controlPort = 9052;
        _socksPort = 9050;

        _thread = [[TORThread alloc] initWithArguments:@[@"DataDirectory", _dataDirectory, @"SocksPort", @(_socksPort), @"ControlPort", [@(_controlPort) stringValue], @"CookieAuthentication", @"1"]];
        [_thread start];
        [self performSelector:@selector(connect) withObject:nil afterDelay:0.1f];
    }
    return self;
}

- (void)dealloc {
    if (_channel)
        dispatch_io_close(_channel, 0);
}

- (NSString *)cookie {
    NSString *cookiePath = [_dataDirectory stringByAppendingPathComponent:@"control_auth_cookie"];
    NSData *cookie = [NSData dataWithContentsOfFile:cookiePath];
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger idx = 0; idx < cookie.length; idx++)
        [hex appendString:[NSString stringWithFormat:@"%02x", ((const unsigned char *)cookie.bytes)[idx]]];
    return hex;
}

- (void)connect {
    if (_channel) {
        return;
    }

    struct sockaddr_in control_addr = {};
    control_addr.sin_len = (__uint8_t)sizeof(control_addr);
    control_addr.sin_family = AF_INET;
    control_addr.sin_port = htons(_controlPort);
    control_addr.sin_addr.s_addr = inet_addr("127.0.0.1");

    int sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);

    int result = connect(sock, (struct sockaddr *)&control_addr, sizeof(control_addr));

    if (result != 0)
        return;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _channel = dispatch_io_create(DISPATCH_IO_STREAM, sock, queue, ^(int error) {
        close(sock);
    });

    dispatch_io_set_low_water(_channel, 1);
    dispatch_io_read(_channel, 0, SIZE_MAX, queue, ^(bool done, dispatch_data_t data, int error) {
        const void *buffer = NULL;
        size_t size = 0;
        __unused dispatch_data_t mapped = dispatch_data_create_map(data, &buffer, &size);
        NSString *response = [[NSString alloc] initWithBytes:buffer length:size encoding:NSUTF8StringEncoding];
        NSMutableString *content = [NSMutableString string];
        for (NSString *line in [response componentsSeparatedByString:@"\r\n"]) { // TODO: Slice off partial line
            if (line.length > 3) {
                NSInteger code = [[line substringToIndex:4] integerValue];
                NSString *separator = [line substringWithRange:NSMakeRange(3, 1)];
                NSCharacterSet *separatorSet = [NSCharacterSet characterSetWithCharactersInString:@"+- "];
                if ([separatorSet characterIsMember:[separator characterAtIndex:0]]) {
                    [content appendString:[line substringFromIndex:4]];
                }
                if ([separator isEqualToString:@" "]) {
                    [self recievedCode:code withContent:content];
                    content = [NSMutableString string];
                }
            }
        }
    });

    [self sendCommand:@"AUTHENTICATE" arguments:@[self.cookie] data:nil completion:^{
        [self sendCommand:@"SETEVENTS" arguments:@[@"STATUS_CLIENT"] data:nil completion:nil];
    }];
}

#pragma mark - Receiving

// TODO: Fix receiving

- (void)receivedStatusEventOfType:(NSString *)type severity:(NSString *)severity action:(NSString *)action arguments:(NSDictionary *)arguments {
    if ([type isEqualToString:@"STATUS_CLIENT"]) {
        if ([severity isEqualToString:@"NOTICE"]) {
            if ([action isEqualToString:@"CIRCUIT_ESTABLISHED"]) {
                self.circuitEstablished = YES;
            } else if ([action isEqualToString:@"CIRCUIT_NOT_ESTABLISHED"]) {
                self.circuitEstablished = NO;
            }
        }
    }
}

- (void)recievedCode:(NSInteger)code withContent:(NSString *)content {
    switch (code) {
        case 650: {
            NSArray *components = [content componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"+- "]];
            if ([components.firstObject hasPrefix:@"STATUS_"]) {
                NSString *severity = components[1];
                NSString *action = components[2];
                [self receivedStatusEventOfType:components.firstObject severity:severity action:action arguments:nil];
            }
            break;
        }

        default:
            break;
    }
}

#pragma mark - Sending

- (void)sendSignal:(NSString *)signal completion:(void(^)())completion {
    NSParameterAssert(signal);
    [self sendCommand:@"SIGNAL" arguments:@[signal] data:nil completion:completion];
}

- (void)sendCommand:(NSString *)command arguments:(NSArray *)arguments data:(NSString *)dataString completion:(void(^)())completion {
    if (!_channel) {
        if (completion) {
            completion();
        }
        return;
    }

    NSParameterAssert(command);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    command = [[@[command] arrayByAddingObjectsFromArray:arguments] componentsJoinedByString:@" "];
    command = [NSString stringWithFormat:@"%@%@\r\n%@%@", dataString.length ? @"+" : @"", command, dataString ?: @"", dataString.length ? @"\r\n.\r\n" : @"" ];
    NSData *commandData = [command dataUsingEncoding:NSUTF8StringEncoding];
    dispatch_data_t data = dispatch_data_create(commandData.bytes, commandData.length, queue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    dispatch_io_write(_channel, 0, data, queue, ^(bool done, dispatch_data_t data, int error) {
        if (completion) {
            completion();
        }
    });
}

@end

