/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>

/**
 * Media format type
 */
enum IMAGE_FORMAT : NSInteger {
    CODE_JPEG,
    CODE_MPEG,
};

/**
 * Information class of media file
 */
@interface HttpImageInfo : NSObject

/**
 * Media format
 */
@property (nonatomic) enum IMAGE_FORMAT file_format;
/**
 * File size
 */
@property (nonatomic) NSUInteger file_size;
/**
 * Image width
 */
@property (nonatomic) NSUInteger image_pix_width;
/**
 * Image height
 */
@property (nonatomic) NSUInteger image_pix_height;
/**
 * File name
 */
@property (nonatomic) NSString* file_name;
/**
 * File creation/update time
 */
@property (nonatomic) NSDate* capture_date;
/**
 * File ID
 */
@property (nonatomic) NSString* file_id;

@end
