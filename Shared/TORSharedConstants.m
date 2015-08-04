//
//  TORSharedConstants.m
//  Tor
//
//  Created by Conrad Kramer on 8/3/15.
//
//

#import "TORSharedConstants.h"

#define TOR_MACRO_STRING_(m) #m
#define TOR_MACRO_STRING(m) @"TOR_MACRO_STRING_(m)"

NSString * const TORAppGroupIdentifier = TOR_MACRO_STRING(TOR_APPLICATION_GROUP);
