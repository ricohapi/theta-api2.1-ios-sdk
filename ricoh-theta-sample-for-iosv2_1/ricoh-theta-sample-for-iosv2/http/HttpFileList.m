      /*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "HttpFileList.h"
#import "HttpImageInfo.h"

/**
 * Acquisition class of media file information<p>
 * If an acquisition method is called after an instance is generated, acquisition begins from the start of the list. Subsequent acquisitions begin from the token position that has been kept<p>
 * Nil is returned by the acquisition method when acquisition of the information reaches the end of the list. This value is therefore used to judge whether acquisition has reached the end.
 */
@interface HttpFileList()
{
    NSUInteger _currentToken;
    NSMutableURLRequest *_request;
    NSURLSession *_session;
}
@end

@implementation HttpFileList

/**
 * Specified initializer
 * @param request HTTP request
 * @return Instance
 */
- (id)initWithRequest:(NSMutableURLRequest*)request
{
    if ([super init]) {
        _currentToken = 0;
        _request = request;
        
        // Create and keep HTTP session
        NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session= [NSURLSession sessionWithConfiguration:config];
        
        _infoArray = nil;
    }
    return self;
}

/**
 * Acquire information on multiple files together
 * @param numItems Number of files for which to acquire information
 * @return Newly acquired token. Nil returned when acquisition reaches end of list
 */
- (NSUInteger*)getList:(NSUInteger)numItems
{
    // Generate NSMutableArray first time only
    if (_infoArray == nil) {
        _infoArray = [NSMutableArray arrayWithCapacity:numItems];
    }
    
    // Semaphore for synchronization
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // Create JSON data
    NSDictionary *body = @{@"name": @"camera.listFiles",
                           @"parameters":
                               @{@"entryCount":[NSNumber numberWithUnsignedInteger:numItems], // Number of still image and video files to be acquired
                                 @"startPosition": [NSNumber numberWithUnsignedInteger: _currentToken], // Token for resuming loading from previous _listAll
                                 @"fileType":@"all",
                                 @"maxThumbSize":@0,
                                 @"_detail": @YES}                     // Acquire file details?
                           };
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    // Set the request-body.
    [_request setHTTPBody:json];
    
    // Send the url-request.
    NSURLSessionDataTask* task =
    [_session dataTaskWithRequest:_request
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    if (!error) {
                        NSArray* array = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                        NSArray* results = [array valueForKey:@"results"];
                        NSArray* entries = [results valueForKey:@"entries"];
                        _currentToken = [results valueForKey:@"startPosition"];
                        
                        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                        [formatter setDateFormat:@"yyyy:MM:dd HH:mm:ssZ"];
                        
                        // Repeat for each acquired object
                        NSUInteger entriesCount = [entries count];
                        for (int i = 0; i < entriesCount; i++) {
                            NSArray* entry = [entries objectAtIndex:i];
                            HttpImageInfo* info = [[HttpImageInfo alloc] init];
                            info.file_name = [entry valueForKey:@"name"];
                            info.file_id = [entry valueForKey:@"fileUrl"];
                            info.file_size = [[entry valueForKey:@"size"] longValue]; // File size (bytes)
                            info.capture_date = [formatter dateFromString:[entry valueForKey:@"dateTimeZone"]];
                            info.image_pix_width = [[entry valueForKey:@"width"] longValue];
                            info.image_pix_height = [[entry valueForKey:@"height"] longValue];
                            info.file_format = [entry valueForKey:@"_recordTime"] ? CODE_MPEG : CODE_JPEG;
                            [self->_infoArray addObject:info];
                        }
                        NSLog(@"result: %@", entries);
                    } else {
                        NSLog(@"error: %@", error);
                    }
                    dispatch_semaphore_signal(semaphore);
                }];
    [task resume];
    
    // Wait until finished using semaphore
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return _currentToken;
}

@end
