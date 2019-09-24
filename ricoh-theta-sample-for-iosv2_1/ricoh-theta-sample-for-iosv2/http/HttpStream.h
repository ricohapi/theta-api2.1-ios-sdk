/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>

@interface HttpStream : NSObject

- (void)setDelegate:(void(^)(NSData *frameData))bufferBlock;

- (id)initWithRequest:(NSMutableURLRequest*)request;

- (void)getData;

- (void)cancel;

@end
