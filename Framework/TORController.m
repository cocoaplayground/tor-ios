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

typedef BOOL (^TORObserverBlock)(NSUInteger code, NSData *data, BOOL *stop);

static NSString * const TORControllerMidReplyLineSeparator = @"-";
static NSString * const TORControllerDataReplyLineSeparator = @"+";
static NSString * const TORControllerEndReplyLineSeparator = @" ";

@implementation TORController {
    NSString *_controlSocketPath;
    NSString *_socksSocketPath;
    TORThread *_thread;
    
    NSString *_dataDirectory;
    dispatch_io_t _channel;
    NSMutableArray *_blocks;
}

+ (dispatch_queue_t)controlQueue {
    static dispatch_queue_t controlQueue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controlQueue = dispatch_queue_create("org.torproject.ios.control", DISPATCH_QUEUE_SERIAL);
    });
    return controlQueue;
}

- (instancetype)init {
    return [self initWithDataDirectory:nil];
}

- (instancetype)initWithDataDirectory:(NSString *)dataDirectory {
    self = [super init];
    if (self) {
        _blocks = [NSMutableArray new];
        _dataDirectory = dataDirectory;
        _controlSocketPath = [_dataDirectory stringByAppendingPathComponent:@"control"];
        _socksSocketPath = [_dataDirectory stringByAppendingPathComponent:@"socks"];

        _thread = [[TORThread alloc] initWithArguments:@[@"--ignore-missing-torrc",
                                                         @"--DataDirectory", @([_dataDirectory fileSystemRepresentation]),
                                                         @"--SocksPort", [NSString stringWithFormat:@"unix:%s", _socksSocketPath.fileSystemRepresentation],
                                                         @"--ControlSocket", @([_controlSocketPath fileSystemRepresentation]),
                                                         @"--CookieAuthentication", @"1"]];
        [_thread start];
    }
    return self;
}

- (void)dealloc {
    if (_channel)
        dispatch_io_close(_channel, DISPATCH_IO_STOP);
}

- (NSData *)cookie {
    NSString *cookiePath = [_dataDirectory stringByAppendingPathComponent:@"control_auth_cookie"];
    return [NSData dataWithContentsOfFile:cookiePath];
}

- (BOOL)isConnected {
    return (_channel != nil);
}

- (BOOL)connect {
    if (_channel)
        return NO;
    
    struct sockaddr_un control_addr = {};
    control_addr.sun_family = AF_UNIX;
    strncpy(control_addr.sun_path, _controlSocketPath.fileSystemRepresentation, sizeof(control_addr.sun_path) - 1);
    control_addr.sun_len = SUN_LEN(&control_addr);
    
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    
    if (connect(sock, (struct sockaddr *)&control_addr, control_addr.sun_len) == -1)
        return NO;

    __weak TORController *weakSelf = self;
    _channel = dispatch_io_create(DISPATCH_IO_STREAM, sock, [[self class] controlQueue], ^(int error) {
        close(sock);
        
        TORController *strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf->_channel = nil;
        }
    });
    
    NSData *separator = [NSData dataWithBytes:"\x0d\x0a" length:2];
    NSSet *lineSeparators = [NSSet setWithObjects:TORControllerMidReplyLineSeparator,
                             TORControllerDataReplyLineSeparator,
                             TORControllerEndReplyLineSeparator, nil];
    
    __block NSMutableData *buffer = [NSMutableData new];
    __block NSMutableData *command = nil;
    __block BOOL dataBlock = NO;
    
    dispatch_io_set_low_water(_channel, 1);
    dispatch_io_read(_channel, 0, SIZE_MAX, [[self class] controlQueue], ^(bool done, dispatch_data_t data, int error) {
        [buffer appendData:(NSData *)data];
        
        NSRange separatorRange = NSMakeRange(NSNotFound, 1);
        NSRange remainingRange = NSMakeRange(0, buffer.length);
        while ((separatorRange = [buffer rangeOfData:separator options:0 range:remainingRange]).location != NSNotFound) {
            NSUInteger lineLength = separatorRange.location - remainingRange.location;
            NSRange lineRange = NSMakeRange(remainingRange.location, lineLength);
            remainingRange = NSMakeRange(remainingRange.location + lineLength + separator.length, remainingRange.length - lineLength - separator.length);
            
            NSData *lineData = [buffer subdataWithRange:lineRange];
            
            if (dataBlock) {
                if ([lineData isEqualToData:[NSData dataWithBytes:"." length:1]]) {
                    dataBlock = NO;
                } else {
                    [command appendData:lineData];
                }
                continue;
            }
            
            if (lineData.length < 4)
                continue;
            
            NSString *statusCodeString = [[NSString alloc] initWithData:[lineData subdataWithRange:NSMakeRange(0, 3)] encoding:NSUTF8StringEncoding];
            if ([statusCodeString rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location != NSNotFound)
                continue;
            
            NSString *lineTypeString = [[NSString alloc] initWithData:[lineData subdataWithRange:NSMakeRange(3, 1)] encoding:NSUTF8StringEncoding];
            if (![lineSeparators containsObject:lineTypeString])
                continue;
            
            buffer = [[buffer subdataWithRange:remainingRange] mutableCopy];
            remainingRange.location = 0;
            
            if (!command)
                command = [NSMutableData new];
            
            [command appendData:[lineData subdataWithRange:NSMakeRange(4, lineData.length - 4)]];
            
            if ([lineTypeString isEqualToString:TORControllerDataReplyLineSeparator]) {
                dataBlock = YES;
            }
            
            if ([lineTypeString isEqualToString:TORControllerEndReplyLineSeparator]) {
                NSUInteger statusCode = [statusCodeString integerValue];
                NSData *commandData = [command copy];
                command = nil;
                
                TORController *strongSelf = weakSelf;
                if (!strongSelf)
                    continue;
                
                for (TORObserverBlock observer in [strongSelf->_blocks copy]) {
                    BOOL stop = NO;
                    BOOL handled = observer(statusCode, commandData, &stop);
                    if (stop)
                        [strongSelf->_blocks removeObject:observer];
                    if (handled)
                        break;
                }
            }
        }
    });

    [self authenticateWithData:self.cookie completion:nil];
    [self sendCommand:@"SETEVENTS" arguments:@[@"CIRC",
                                               @"STREAM",
                                               @"ORCONN",
                                               @"BW",
                                               @"NEWDESC",
                                               @"ADDRMAP",
                                               @"AUTHDIR_NEWDESCS",
                                               @"DESCCHANGED",
                                               @"STATUS_GENERAL",
                                               @"STATUS_CLIENT",
                                               @"STATUS_SERVER",
                                               @"GUARD",
                                               @"NS",
                                               @"STREAM_BW",
                                               @"CLIENTS_SEEN",
                                               @"NEWCONSENSUS",
                                               @"BUILDTIMEOUT_SET",
                                               @"SIGNAL",
                                               @"CONF_CHANGED",
                                               @"CIRC_MINOR",
                                               @"TRANSPORT_LAUNCHED",
                                               @"CELL_STATS",
                                               @"TB_EMPTY",
                                               @"HS_DESC"] data:nil observer:nil];
    
    return YES;
}

#pragma mark - Receiving

- (id)addObserverForCircuitEstablished:(void (^)(BOOL established))block {
    NSParameterAssert(block);
    return [self addObserverForStatusEvents:^(NSString *type, NSString *severity, NSString *action, NSDictionary *arguments) {
        if ([type isEqualToString:@"STATUS_CLIENT"]) {
            if ([action isEqualToString:@"CIRCUIT_ESTABLISHED"]) {
                block(YES);
                return YES;
            } else if ([action isEqualToString:@"CIRCUIT_NOT_ESTABLISHED"]) {
                block(NO);
                return YES;
            }
        }
        
        return NO;
    }];
}

- (id)addObserverForStatusEvents:(BOOL (^)(NSString *type, NSString *severity, NSString *action, NSDictionary *arguments))block {
    NSParameterAssert(block);
    return [self addObserver:^(NSUInteger code, NSData *data, BOOL *stop) {
        if (code != 650)
            return NO;
        
        NSString *replyString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (![replyString hasPrefix:@"STATUS_"])
            return NO;
        
        NSArray *components = [replyString componentsSeparatedByString:@" "];
        if (components.count < 3)
            return NO;
            
        NSMutableDictionary *arguments = nil;
        if (components.count > 3) {
            arguments = [NSMutableDictionary new];
            for (NSString *argument in [components subarrayWithRange:NSMakeRange(3, components.count - 3)]) {
                NSArray *keyValuePair = [argument componentsSeparatedByString:@"="];
                if (keyValuePair.count == 2) {
                    [arguments setObject:keyValuePair[1] forKey:keyValuePair[0]];
                }
            }
        }
        
        return block(components.firstObject, components[1], components[2], arguments);
    }];
}

- (id)addObserver:(TORObserverBlock)observer {
    NSParameterAssert(observer);
    dispatch_async([[self class] controlQueue], ^{
        [_blocks addObject:observer];
    });
    return observer;
}

- (void)removeObserver:(id)observer {
    NSParameterAssert(observer);
    dispatch_async([[self class] controlQueue], ^{
        [_blocks removeObject:observer];
    });
}

#pragma mark - Sending

- (void)authenticateWithData:(NSData *)data completion:(void (^)(BOOL success, NSString *message))completion {
    NSMutableString *hexString = [NSMutableString new];
    for (NSUInteger idx = 0; idx < data.length; idx++)
        [hexString appendFormat:@"%02x", ((const unsigned char *)data.bytes)[idx]];
    
    [self sendCommand:@"AUTHENTICATE" arguments:(hexString.length ? @[hexString] : nil) data:nil observer:^BOOL(NSUInteger code, NSData *data, BOOL *stop) {
        if (code != 250 && code != 515)
            return NO;
        
        NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        BOOL success = (code == 250 && [message isEqualToString:@"OK"]);
        if (completion)
            completion(success, success ? nil : message);
        
        *stop = YES;
        return YES;
    }];
}

- (void)sendCommand:(NSString *)command arguments:(NSArray *)arguments data:(NSData *)data observer:(TORObserverBlock)observer {
    NSParameterAssert(command.length);
    if (!_channel)
        return;
    
    NSString *argumentsString = [[@[command] arrayByAddingObjectsFromArray:arguments] componentsJoinedByString:@" "];
    
    NSMutableData *commandData = [NSMutableData new];
    if (data.length) {
        [commandData appendBytes:"+" length:1];
    }
    [commandData appendData:[argumentsString dataUsingEncoding:NSUTF8StringEncoding]];
    [commandData appendBytes:"\r\n" length:2];
    if (data.length) {
        [commandData appendData:data];
        [commandData appendBytes:"\r\n.\r\n" length:5];
    }
    
    dispatch_data_t dispatchData = dispatch_data_create(commandData.bytes, commandData.length, [[self class] controlQueue], DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    dispatch_io_write(_channel, 0, dispatchData, [[self class] controlQueue], ^(bool done, dispatch_data_t data, int error) {
        if (done && !error && observer) {
            [_blocks insertObject:observer atIndex:0];
        }
    });
}

@end

