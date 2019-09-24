/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "ImageViewController.h"
#import "glkViewController.h"
#import "GLRenderView.h"
#import "SphereXmp.h"
#import "HttpImageInfo.h"


@interface ImageViewController ()
{
    HttpImageInfo *_httpImageInfo;
    HttpSession *_session;
    NSMutableData *_imageData;
    int imageWidth;
    int imageHeight;
    GlkViewController *_glkViewController;
    float _yaw;
    float _roll;
    float _pitch;
}
@end

@implementation ImageViewController

- (void)appendLog:(NSString*)text
{
    [_textView setText:[NSString stringWithFormat:@"%@%@\n", _textView.text, text]];
    [_textView scrollRangeToVisible:NSMakeRange([_textView.text length], 0)];
}

#pragma mark - UI events

- (void)onCloseClicked:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)myCloseClicked:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onConfig:(id)sender {
}

- (void)myConfig:(id)sender {
    NSLog(@"myConfig");

    // Set text style according to current settings
    int current = (_glkViewController.glRenderView.kindInertia);
    UIAlertActionStyle noneStyle = (current == NoneInertia) ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
    UIAlertActionStyle weakStyle = (current == ShortInertia) ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
    UIAlertActionStyle strongStyle = (current == LongInertia) ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Inertia"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* noneAction = [UIAlertAction actionWithTitle:@"none"
                                                         style:noneStyle
                                                       handler:^(UIAlertAction *action) {
                                                           NSLog(@"noInertia");
                                                           _glkViewController.glRenderView.kindInertia = NoneInertia;
                                                       }];
    UIAlertAction* weakAction = [UIAlertAction actionWithTitle:@"weak"
                                                         style:weakStyle
                                                       handler:^(UIAlertAction *action) {
                                                           NSLog(@"shortInertia");
                                                           _glkViewController.glRenderView.kindInertia = ShortInertia;
                                                       }];
    UIAlertAction* strongAction = [UIAlertAction actionWithTitle:@"strong"
                                                           style:strongStyle
                                                         handler:^(UIAlertAction *action) {
                                                             NSLog(@"longInertia");
                                                             _glkViewController.glRenderView.kindInertia = LongInertia;
                                                         }];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:noneAction];
    [alert addAction:weakAction];
    [alert addAction:strongAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - HTTP Operation

- (void)getObject:(HttpImageInfo *)imageInfo withSession:(HttpSession *)session
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _progressView.progress = 0.0;
        _progressView.hidden = NO;
    });

    _httpImageInfo = imageInfo;
    _session = session;
    NSString *fileUrl = imageInfo.file_id;
    // Semaphore for synchronization (cannot be entered until signal is called)
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [session getResizedImageObject:fileUrl
                           onStart:^(int64_t totalLength) {
                               // Callback before object-data reception.
                               NSLog(@"getObject(%@) will received %zd bytes.", fileUrl, totalLength);
                           }
                           onWrite:^(int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
                               // Callback for each chunks.
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   // Update progress.
                                   _progressView.progress = (float)totalBytesWritten / totalBytesExpectedToWrite;
                               });
                           }
                          onFinish:^(NSURL *location){
                              _imageData = [NSMutableData dataWithContentsOfURL:[NSURL URLWithString:fileUrl]];
                              dispatch_semaphore_signal(semaphore);
                          }];
    
    // Wait until signal is called
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    // Parse XMP data, it contains the data to correct the tilt.
    SphereXmp *xmp = [[SphereXmp alloc] init];
    [xmp parse:_imageData];
    
    // If there is no information, yaw, pitch and roll method returns NaN.
    NSString* tiltInfo = [NSString stringWithFormat:@"yaw:%@ pitch:%@ roll:%@",
                          xmp.yaw, xmp.pitch, xmp.roll];

    _yaw = [xmp.yaw floatValue];     // 0.0 if conversion fails
    _pitch = [xmp.pitch floatValue]; // 0.0 if conversion fails
    _roll = [xmp.roll floatValue];   // 0.0 if conversion fails
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _progressView.hidden = YES;
        [self appendLog:tiltInfo];
        [self startGLK];
    });
}

#pragma mark - Life cycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
}


- (void)viewWillAppear:(BOOL)animated {
    if (nil != _httpImageInfo && CODE_JPEG == _httpImageInfo.file_format) {
        _progressView.hidden = NO;
    }
    else {
        _progressView.hidden = YES;
    }

}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    _textView.text = nil;
    _imageView.image = nil;
}

#pragma make - operation

- (void)startGLK
{
    _glkViewController = [[GlkViewController alloc] init:_imageView.frame image:_imageData width:imageWidth height:imageHeight yaw:_yaw roll:_roll pitch:_pitch];
    
    [self addChildViewController:_glkViewController];
    [self.view addSubview:_glkViewController.view];
    _glkViewController.view.frame = _imageView.frame;
    
    UIButton *myButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    myButton.frame = _closeButton.frame;
    [myButton setTitle:_closeButton.currentTitle forState:UIControlStateNormal];
    [myButton addTarget:self action:@selector(myCloseClicked:) forControlEvents:UIControlEventTouchUpInside];
    [_glkViewController.view addSubview:myButton];
    
    UIButton *myConfigButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    myConfigButton.frame = _configButton.frame;
    [myConfigButton setTitle:_configButton.currentTitle forState:UIControlStateNormal];
    [myConfigButton addTarget:self action:@selector(myConfig:) forControlEvents:UIControlEventTouchUpInside];
    [_glkViewController.view addSubview:myConfigButton];
    
    [_glkViewController didMoveToParentViewController:self];
}

@end
