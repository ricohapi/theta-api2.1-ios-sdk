/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>

/**
 * Class for downloading files via HTTP
 */
@interface HttpSession : NSObject

- (id)initWithRequest:(NSMutableURLRequest*)request;

- (void)getResizedImageObject:(NSString*)fileUrl
                      onStart:(void(^)(int64_t expectedTotalBytes))startBlock
                      onWrite:(void(^)(int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite))writeBlock
                     onFinish:(void(^)(NSURL *location))finishBlock;

@end
