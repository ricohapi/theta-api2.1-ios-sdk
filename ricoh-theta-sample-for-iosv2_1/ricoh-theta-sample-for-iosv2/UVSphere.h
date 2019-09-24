/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>

#ifndef ricoh_theta_sample_for_ios_UVSphere_h
#define ricoh_theta_sample_for_ios_UVSphere_h

@interface UVSphere : NSObject

-(id) init:(GLfloat)radius divide:(int)divide rotate:(double)rotate;

-(void) draw:(GLint) posLocation uv:(GLint) uvLocation;

@end

#endif
