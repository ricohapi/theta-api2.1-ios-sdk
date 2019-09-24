/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>

@interface HttpFileList : NSObject

@property (readonly) NSMutableArray *infoArray;


- (id)initWithRequest:(NSMutableURLRequest*)request;

- (NSUInteger*)getList:(NSUInteger)numItems;

@end
