/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "ViewController.h"
#import "TableCell.h"
#import "ImageViewController.h"
#import "HttpConnection.h"
#import "TableCellObject.h"

inline static void dispatch_async_main(dispatch_block_t block)
{
    dispatch_async(dispatch_get_main_queue(), block);
}

inline static void dispatch_async_default(dispatch_block_t block)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>
{
    NSMutableArray* _objects;
    HttpStorageInfo* _storageInfo;
    NSNumber* _batteryLevel;
    HttpConnection* _httpConnection;
}
@property(nonatomic,weak)IBOutlet UIView *toastView;

@end

@implementation ViewController

- (void)appendLog:(NSString*)text
{
    [_logView setText:[NSString stringWithFormat:@"%@%@\n", _logView.text, text]];
    [_logView scrollRangeToVisible:NSMakeRange([_logView.text length], 0)];
}

#pragma mark - UI events.

- (void)onConnetClicked:(id)sender
{
    [_ipField resignFirstResponder];
    // Disable Connect button
    self.connectButton.enabled = NO;
    
    [self appendLog:[NSString stringWithFormat:@"connecting %@...", _ipField.text]];
    
    // Setup `target IP`(camera IP).
    // Product default is "192.168.1.1".
    [_httpConnection setTargetIp:_ipField.text];
    
    //Previewの表示
    [self enumerateImages];
}

- (IBAction)onCaptureClicked:(id)sender
{
    // Disable Capture button and Disconnect button
    
    UIButton *senderButton = sender;
    senderButton.enabled = NO;
    self.connectButton.enabled = NO;
    
    dispatch_async_default(^{
        // Start shooting process
        HttpImageInfo *info = [_httpConnection takePicture];
        
        if (info != nil) {
            TableCellObject* object = [TableCellObject objectWithInfo:info];
            NSData* thumbData = [_httpConnection getThumb:info.file_id];
            object.thumbnail =[UIImage imageWithData:thumbData];
            [_objects insertObject:object atIndex:0];
            
            NSIndexPath* pos = [NSIndexPath indexPathForRow:0 inSection:1];
            dispatch_async_main(^{
                [_contentsView insertRowsAtIndexPaths:@[pos]
                                     withRowAnimation:UITableViewRowAnimationRight];
                for (NSInteger i = 1; i < _objects.count; ++i) {
                    NSIndexPath* path = [NSIndexPath indexPathForRow:i inSection:1];
                    [_contentsView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
                }
            });
        }
        dispatch_async_main(^{
            // Enable Capture button and Disconnect button
            senderButton.enabled = YES;
            self.connectButton.enabled = YES;
            [self appendLog:[NSString stringWithFormat:@"execShutter[result:%@]", info]];
        });
    });
}
 
- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender
{
    TableCell* c = (TableCell*)sender;
    TableCellObject* o = [_objects objectAtIndex:c.objectIndex];

    if (CODE_JPEG == o.objectInfo.file_format) {

        id d = [segue destinationViewController];
        if ([d isKindOfClass:[ImageViewController class]]) {
            ImageViewController* dest = (ImageViewController*)d;
            TableCell* cell = (TableCell*)sender;
            dispatch_async_default(^{
                TableCellObject* object = [_objects objectAtIndex:cell.objectIndex];
                NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
                NSString* file = [NSString stringWithFormat:@"%@",object.objectInfo.file_id];
                NSURL *url = [NSURL URLWithString:file];
                
                request = [NSMutableURLRequest requestWithURL:url];
                HttpSession *session = [[HttpSession alloc] initWithRequest:request];
                
                [dest getObject:object.objectInfo withSession:session];
            });
        }
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"SegueViewControllerToImageViewControllerID"]) {
        TableCell* c = (TableCell*)sender;
        TableCellObject* o = [_objects objectAtIndex:c.objectIndex];
        
        if (CODE_JPEG != o.objectInfo.file_format) {
            [self showToast];
            return NO;
        }
    }
    return YES;
}

#pragma mark - HTTP Operations.

- (void)disconnect
{
    [self appendLog:@"disconnecting..."];
    
    [_httpConnection close:^{
        // "CloseSession" and "Close" completion callback.
        
        dispatch_async_main(^{
            _captureButton.enabled = NO;
            _imageSizeButtom.enabled = NO;
            _motionJpegView.image = nil;
            [self appendLog:@"disconnected."];
            [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
            [_objects removeAllObjects];
            [_contentsView reloadData];
        });
    }];
}

- (void)enumerateImages
{
    [_objects removeAllObjects];

    [_httpConnection getDeviceInfo:^(const HttpDeviceInfo* info) {
        // "GetDeviceInfo" completion callback.
        
        dispatch_async_main(^{
            [self appendLog:[NSString stringWithFormat:@"DeviceInfo:%@", info]];
        });
        
    }];
    
    dispatch_async_default(^{
        // Create "Waiting" indicator 
        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
                                              initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        indicator.color = [UIColor grayColor];
        
        dispatch_async_main(^{
            // Set indicator to be displayed in the center of the table view
            float w = indicator.frame.size.width;
            float h = indicator.frame.size.height;
            float x = _contentsView.frame.size.width/2 - w/2;
            float y = _contentsView.frame.size.height/2 - h/2;
            indicator.frame = CGRectMake(x, y, w, h);

            // Start indicator animation
            [_contentsView addSubview:indicator];
            [indicator startAnimating];
        });
        
        // Get storage information.
        _storageInfo = [_httpConnection getStorageInfo];
        
        // Get Battery level.
        _batteryLevel = [_httpConnection getBatteryLevel];
        
        // Get object informations for primary images.
        NSArray* imageInfoes = [_httpConnection getImageInfoes];

        dispatch_async_main(^{
            [self appendLog:[NSString stringWithFormat:@"getImageInfoes() received %zd infoes.", imageInfoes.count]];
        });
        
        // Get thumbnail images for each primary images.
        NSUInteger maxCount = MIN(imageInfoes.count, 30);
        for (NSUInteger i = 0; i < maxCount; ++i) {
            HttpImageInfo *info = [imageInfoes objectAtIndex:i];
            TableCellObject* object = [TableCellObject objectWithInfo:info];
            
            NSData* thumbData = [_httpConnection getThumb:info.file_id];
            object.thumbnail =[UIImage imageWithData:thumbData];
            [_objects addObject:object];
            
            dispatch_async_main(^{
                [self appendLog:[info description]];
                [self appendLog:[NSString stringWithFormat:@"imageInfoes: %ld/%ld", i + 1, maxCount]];
            });
        }
        dispatch_async_main(^{
            // Stop indicator animation
            [indicator stopAnimating];
            
            [_contentsView reloadData];
            
            // Enable Connect button
            self.connectButton.enabled = YES;
            _captureButton.enabled = YES;
            _imageSizeButtom.enabled = YES;
        });
        
        // Start live view display
        [_httpConnection startLiveView:^(NSData *frameData) {
            dispatch_async_main(^{
                UIImage *image = [UIImage imageWithData:frameData];
                _motionJpegView.image = image;
            });
        }];
    });
}

#pragma mark - UITableViewDataSource delegates.

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section==0) {
        return [_httpConnection connected] ? 1: 0;
    }
    return _objects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    TableCell* cell;

    if (indexPath.section==0) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"cameraInfo"];
        cell.textLabel.text = [NSString stringWithFormat:@"%ld[shots] %ld/%ld[MB] free",
                               _storageInfo.free_space_in_images,
                               _storageInfo.free_space_in_bytes/1024/1024,
                               _storageInfo.max_capacity/1024/1024];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"BATT %.0f %%", [_batteryLevel doubleValue]*100.0];
    } else {
        // NSDateFormatter to display photographing date.
        NSDateFormatter* df = [[NSDateFormatter alloc] init];
        [df setDateStyle:NSDateFormatterShortStyle];
        [df setTimeStyle:NSDateFormatterMediumStyle];

        TableCellObject* obj = [_objects objectAtIndex:indexPath.row];
        cell = [tableView dequeueReusableCellWithIdentifier:@"customCell"];
        cell.textLabel.text = [NSString stringWithFormat:@"%@", obj.objectInfo.file_name];
        cell.detailTextLabel.text = [df stringFromDate:obj.objectInfo.capture_date];
        cell.imageView.image = obj.thumbnail;
        cell.objectIndex = (uint32_t)indexPath.row;
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {

    NSIndexPath *path = indexPath;
    NSArray *pathArray = [NSArray arrayWithObject:path];
    dispatch_async_default(^{
        TableCellObject *object = [_objects objectAtIndex:path.row];
        if ([_httpConnection deleteImage:object.objectInfo]) {
            dispatch_async_main(^{
                // Delete data source
                [_objects removeObjectAtIndex:path.row];

                // Delete row from table
                [_contentsView deleteRowsAtIndexPaths:pathArray
                                     withRowAnimation:UITableViewRowAnimationAutomatic];
                for (NSInteger i = path.row; i < _objects.count; ++i) {
                    NSIndexPath* index = [NSIndexPath indexPathForRow:i inSection:path.section];
                    [_contentsView reloadRowsAtIndexPaths:@[index] withRowAnimation:UITableViewRowAnimationTop];
                }
            });
        }
    });
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

#pragma mark - Life cycle.

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _objects = [NSMutableArray array];
    _httpConnection = [[HttpConnection alloc] init];
    _contentsView.dataSource = self;
    _logView.layoutManager.allowsNonContiguousLayout = NO;
    _captureButton.enabled = NO;
    _imageSizeButtom.enabled = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [_httpConnection restartLiveView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)showToast
{
    self.toastView.hidden = NO;
    self.toastView.alpha = 1.0f;
    [UIView animateWithDuration:0.7f delay:3.0f options:(UIViewAnimationOptionAllowUserInteraction) animations:^{
        self.toastView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        self.toastView.hidden = YES;
        self.toastView.alpha = 1.0f;
    }];
}

@end
