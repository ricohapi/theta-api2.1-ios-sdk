/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>

@interface SphereXmp : NSObject

@property NSString *yaw;
@property NSString *pitch;
@property NSString *roll;

- (BOOL)parse:(NSData*)original;
@end
