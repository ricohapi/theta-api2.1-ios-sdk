/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>

@interface HttpStatusTimer : NSObject

@property (readonly) NSString* fileUrl;

- (id)initWithRequest:(NSMutableURLRequest*)request;

- (NSString*)run:(NSString*)command;

@end
