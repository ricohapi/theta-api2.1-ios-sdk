/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <Foundation/Foundation.h>


@interface GLRenderView : GLKView

@property int kindInertia;

-(id) initWithFrame:(CGRect)frame;

-(void) draw;

-(void) setTexture:(NSMutableData*)data width:(int)width height:(int)height yaw:(float)yaw pitch:(float)pitch roll:(float)roll;

- (void)tearDown;
@end

