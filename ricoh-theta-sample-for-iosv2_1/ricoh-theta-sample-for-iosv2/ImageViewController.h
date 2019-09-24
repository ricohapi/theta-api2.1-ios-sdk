/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "HttpSession.h"

@class HttpImageInfo;

#define KINT_HIGHT_INTERVAL_BUTTON  54

typedef enum : int {
    NoneInertia = 0,
    ShortInertia,
    LongInertia
} enumInertia;

@interface ImageViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView* imageView;
@property (nonatomic, strong) IBOutlet UITextView* textView;
@property (nonatomic, strong) IBOutlet UIProgressView* progressView;
@property (nonatomic, strong) IBOutlet UIButton *closeButton;
@property (nonatomic, strong) IBOutlet UIButton *configButton;

- (IBAction)onCloseClicked:(id)sender;
- (void)getObject:(HttpImageInfo *)imageInfo withSession:(HttpSession *)session;
- (IBAction)onConfig:(id)sender;

@end
