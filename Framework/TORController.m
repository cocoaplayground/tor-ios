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

static NSString * const TORControllerMidReplyLineSeparator = @"-";
static NSString * const TORControllerDataReplyLineSeparator = @"+";
static NSString * const TORControllerEndReplyLineSeparator = @" ";

@interface TORController ()

@property (readwrite, nonatomic) BOOL circuitEstablished;

@end

static TORController *sharedController = nil;

@implementation TORController {
    TORThread *_thread;
    NSString *_dataDirectory;
    NSString *_controlSocketPath;
    dispatch_io_t _channel;
}

+ (instancetype)sharedController {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[self alloc] init];
    });
    return sharedController;
}

+ (dispatch_queue_t)eventQueue {
    static dispatch_queue_t eventQueue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        eventQueue = dispatch_queue_create("org.torproject.ios.events", DISPATCH_QUEUE_SERIAL);
    });
    return eventQueue;
}

- (instancetype)init {
    NSAssert(sharedController == nil, @"There can only be one TORController per process");
    self = [super init];
    if (self) {
        _dataDirectory = NSTemporaryDirectory();
        _controlSocketPath = [_dataDirectory stringByAppendingPathComponent:@"control"];
        _socksSocketPath = [_dataDirectory stringByAppendingPathComponent:@"socks"];
        
        _thread = [[TORThread alloc] initWithArguments:@[@"--ignore-missing-torrc",
                                                         @"--DataDirectory", @([_dataDirectory fileSystemRepresentation]),
                                                         @"--SocksPort", [NSString stringWithFormat:@"unix:%s", _socksSocketPath.fileSystemRepresentation],
                                                         @"--ControlSocket", @([_controlSocketPath fileSystemRepresentation]),
                                                         @"--CookieAuthentication", @"1"]];
        [_thread start];
        [self performSelector:@selector(connect) withObject:nil afterDelay:0.1f];
    }
    return self;
}

- (void)dealloc {
    if (_channel)
        dispatch_io_close(_channel, DISPATCH_IO_STOP);
}

- (NSString *)cookie {
    NSString *cookiePath = [_dataDirectory stringByAppendingPathComponent:@"control_auth_cookie"];
    NSData *cookie = [NSData dataWithContentsOfFile:cookiePath];
    if (!cookie)
        return nil;
    
    NSMutableString *hex = [NSMutableString new];
    for (NSUInteger idx = 0; idx < cookie.length; idx++)
        [hex appendFormat:@"%02x", ((const unsigned char *)cookie.bytes)[idx]];
    return hex;
}

- (void)connect {
    if (_channel)
        return;
    
    struct sockaddr_un control_addr = {};
    control_addr.sun_family = AF_UNIX;
    strncpy(control_addr.sun_path, _controlSocketPath.fileSystemRepresentation, sizeof(control_addr.sun_path) - 1);
    control_addr.sun_len = SUN_LEN(&control_addr);
    
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    
    if (connect(sock, (struct sockaddr *)&control_addr, control_addr.sun_len) == -1)
        return [self performSelector:@selector(connect) withObject:nil afterDelay:0.1f]; // TODO: Handle permanent failure

    _channel = dispatch_io_create(DISPATCH_IO_STREAM, sock, [[self class] eventQueue], ^(int error) {
        close(sock);
    });
    
    NSData *separator = [NSData dataWithBytes:"\x0d\x0a" length:2];
    NSSet *lineSeparators = [NSSet setWithObjects:TORControllerMidReplyLineSeparator,
                             TORControllerDataReplyLineSeparator,
                             TORControllerEndReplyLineSeparator, nil];
    
    __block NSMutableData *buffer = [NSMutableData new];
    __block NSMutableData *command = nil;
    __block BOOL dataBlock = NO;
    
    dispatch_io_set_low_water(_channel, 1);
    dispatch_io_read(_channel, 0, SIZE_MAX, [[self class] eventQueue], ^(bool done, dispatch_data_t data, int error) {
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
                [self recievedReplyWithCode:[statusCodeString integerValue] data:command];
                command = nil;
            }
        }
    });

    NSString *cookie = self.cookie;
    if (cookie) {
        [self sendCommand:@"AUTHENTICATE" arguments:@[cookie] data:nil];
        
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
                                                   @"HS_DESC"] data:nil];        
    }
}

#pragma mark - Receiving

- (void)receivedStatusEventOfType:(NSString *)type severity:(NSString *)severity action:(NSString *)action arguments:(NSDictionary *)arguments {
    if ([type isEqualToString:@"STATUS_CLIENT"]) {
        if ([action isEqualToString:@"CIRCUIT_ESTABLISHED"]) {
            self.circuitEstablished = YES;
        } else if ([action isEqualToString:@"CIRCUIT_NOT_ESTABLISHED"]) {
            self.circuitEstablished = NO;
        }
    }
}

- (void)recievedReplyWithCode:(NSUInteger)code data:(NSData *)data {
    NSString *replyString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    switch (code) {
        case 650: {
            if ([replyString hasPrefix:@"STATUS_"]) {
                NSArray *components = [replyString componentsSeparatedByString:@" "];
                if (components.count < 3)
                    return;
                
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
                
                [self receivedStatusEventOfType:components.firstObject severity:components[1] action:components[2] arguments:arguments];
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
    [self sendCommand:@"SIGNAL" arguments:@[signal] data:nil];
}

- (void)sendCommand:(NSString *)command arguments:(NSArray *)arguments data:(NSData *)data {
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
    
    dispatch_data_t dispatchData = dispatch_data_create(commandData.bytes, commandData.length, [[self class] eventQueue], DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    dispatch_io_write(_channel, 0, dispatchData, [[self class] eventQueue], ^(bool done, dispatch_data_t data, int error) {
        
    });
}

@end

