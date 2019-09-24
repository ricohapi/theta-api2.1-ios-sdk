/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HttpImageInfo.h"

@interface TableCellObject : NSObject

@property (nonatomic) UIImage* thumbnail;
@property (nonatomic) HttpImageInfo* objectInfo;

/**
 * Function for object creation
 * @param info
 */
+ (id)objectWithInfo:(HttpImageInfo*)info;

@end
