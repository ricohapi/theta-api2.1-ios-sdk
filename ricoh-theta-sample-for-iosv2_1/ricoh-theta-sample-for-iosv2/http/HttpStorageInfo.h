/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>

/**
 * Device storage information and size of shot image
 */
@interface HttpStorageInfo : NSObject

/**
 * Total storage capacity
 */
@property (nonatomic) unsigned long max_capacity;
/**
 * Remaining capacity
 */
@property (nonatomic) unsigned long free_space_in_bytes;
/**
 * Remaining number of photos
 */
@property (nonatomic) unsigned long free_space_in_images;
/**
 * Image width for shooting still images
 */
@property (nonatomic) unsigned long image_width;
/**
 * Image height for shooting still images
 */
@property (nonatomic) unsigned long image_height;

@end
