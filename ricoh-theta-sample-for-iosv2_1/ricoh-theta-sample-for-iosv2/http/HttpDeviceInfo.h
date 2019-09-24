/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>

/**
 * Device information class
 */
@interface HttpDeviceInfo : NSObject

/**
 * Model name
 */
@property (nonatomic) NSString* model;
/**
 * Firmware version
 */
@property (nonatomic) NSString* firmware_version;
/**
 * Serial number
 */
@property (nonatomic) NSString* serial_number;

/**
 * Device information represented as character string
 */
- (NSString*)description;

@end
