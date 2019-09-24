/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "HttpImageInfo.h"

@implementation HttpImageInfo

-(NSString*)description
{
    NSMutableString* s = [NSMutableString stringWithString:@"<HttpImageInfo: "];
    [s appendFormat:@" file_name=%@", _file_name];
    [s appendFormat:@" capture_date=%@", _capture_date];
    [s appendFormat:@" file_id=%@", _file_id];
    [s appendFormat:@" file_size=%tu", _file_size];
    [s appendFormat:@" image_pix_width=%tu", _image_pix_width];
    [s appendFormat:@" image_pix_height=%tu", _image_pix_height];
    [s appendFormat:@" file_format=%tx", _file_format];
    [s appendString:@" >"];
    return s;
}

@end
