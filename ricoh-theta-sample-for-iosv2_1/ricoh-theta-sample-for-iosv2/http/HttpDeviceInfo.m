/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "HttpDeviceInfo.h"

@implementation HttpDeviceInfo

- (NSString*)description
{
    NSMutableString* string = [NSMutableString string];
    [string appendFormat:@" model=%@", self->_model];
    [string appendFormat:@" firmware_version=%@", self->_firmware_version];
    [string appendFormat:@" serial_number=%@", self->_serial_number];
    return string;
}

@end
