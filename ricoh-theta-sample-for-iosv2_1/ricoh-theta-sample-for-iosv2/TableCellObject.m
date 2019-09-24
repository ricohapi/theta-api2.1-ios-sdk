/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "TableCellObject.h"

@implementation TableCellObject

+ (id)objectWithInfo:(HttpImageInfo*)info
{
    TableCellObject *object = [[TableCellObject alloc] init];
    object.objectInfo = info;
    return object;
}

@end
