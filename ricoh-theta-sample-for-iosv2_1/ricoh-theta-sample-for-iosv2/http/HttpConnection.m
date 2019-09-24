/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "HttpConnection.h"
#import "HttpStatusTimer.h"
#import "HttpFileList.h"
#import "HttpStream.h"

/**
 * HTTP connection to device
 */
@interface HttpConnection ()
{
    NSString *_server;
    NSURLSession *_session;
    NSMutableArray *_infoArray;
    HttpStream *_stream;
}
@end

@implementation HttpConnection

#pragma mark - Accessors.

/**
 * Specify address of connection destination
 * @param address Address
 */
- (void)setTargetIp:(NSString* const)address;
{
    _server = address;
}

/**
 * Status of connection to device
 * @return YES:Connect, NO:Disconnect
 */
- (BOOL)connected
{
    return (_sessionId != nil);
}

#pragma mark - Life cycle.

/**
 * Initializer
 * @return Instance
 */
- (id)init
{
    if (self = [super init]) {
        // Timeout settings
        NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 5.0;

        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

#pragma mark - HTTP Connections.

/**
 * Notify device of continuation of session
 */
- (void)update
{
    if (_sessionId) {
        // Create the url-request.
        NSMutableURLRequest *request = [self createExecuteRequest];

        // Create JSON data
        NSDictionary *body = @{@"name":@"camera.updateSession",
                               @"parameters":
                                   @{@"sessionId":_sessionId}};
        NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

        // Set the request-body.
        [request setHTTPBody:json];

        // Send the url-request.
        NSURLSessionDataTask* task =
        [_session dataTaskWithRequest:request
                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                        NSString *newId = nil;
                        if (!error) {
                            NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                            newId = [array valueForKeyPath:@"results.sessionId"];
                            NSLog(@"result: %@", newId);
                        } else {
                            NSLog(@"error: %@", error);
                        }

                        if (newId) {
                            _sessionId = newId;
                        }
                    }];
        [task resume];
    }
}

/**
 * Disconnect from device
 * @param block Block called after disconnection process
 */
- (void)close:(void(^ const)())block
{
    if (self->_sessionId) {
        // Stop live view
        [_stream cancel];

        // Create the url-request.
        NSMutableURLRequest *request = [self createExecuteRequest];

        // Create JSON data
        NSDictionary *body = @{
          @"name":@"camera.closeSession",
          @"parameters":
              @{ @"sessionId":self->_sessionId }
        };
        NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

        // Set the request-body.
        [request setHTTPBody:json];

        // Send the url-request.
        NSURLSessionDataTask* task =
        [self->_session dataTaskWithRequest:request
                         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                             block();
                         }];
        [task resume];
        self->_sessionId = nil;
    }
}

/**
 * Acquire device information
 * @param block Block to be called after acquisition process
 */
- (void)getDeviceInfo:(void(^const )(const HttpDeviceInfo* const info))block
{
    // Create the url-request.
    NSMutableURLRequest *request = [self createRequest:@"/osc/info" method:@"GET"];

    // Do not set body for GET requests

    // Send the url-request.
    NSURLSessionDataTask* task =
    [self->_session dataTaskWithRequest:request
                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                          HttpDeviceInfo* info = [[HttpDeviceInfo alloc] init];
                          if (!error) {
                              NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                              info.model = [array valueForKeyPath:@"model"];
                              info.firmware_version = [array valueForKeyPath:@"firmwareVersion"];
                              info.serial_number = [array valueForKeyPath:@"serialNumber"];
                              NSLog(@"result: %@", data);
                          } else {
                              NSLog(@"error: %@", error);
                          }
                          block(info);
                      }];
    [task resume];
}

/**
 * Acquire list of media files on device
 * @return Media file list
 */
- (NSArray*)getImageInfoes
{
    // Create the url-request.
    NSMutableURLRequest *request = [self createExecuteRequest];
    HttpFileList *fileList = [[HttpFileList alloc] initWithRequest:request];

    NSUInteger* token;
    do {
        token = [fileList getList:10];
    } while (token);
    return fileList.infoArray;
}

/**
 * Acquire thumbnail image
 * @param fileId File ID
 * @return Thumbnail
 */
- (NSData*)getThumb:(NSString*)fileId
{
    // Semaphore for synchronization (cannot be entered until signal is called)
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // Create the url-request.
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

    if(fileId != NULL){
        NSString* thumbFile = [NSString stringWithFormat:@"%@%@",fileId,@"?type=thumb"];
       // request = [self createRequest:thumbFile method:@"GET"];
        
        NSURL *url = [NSURL URLWithString:thumbFile];
        
        // Create the url-request.
        request = [NSMutableURLRequest requestWithURL:url];
        
        // Set the method(HTTP-POST)
        [request setHTTPMethod:@"GET"];
        
        [request setValue:@"application/json; charaset=utf-8" forHTTPHeaderField:@"Content-Type"];

    }
    
    // Create JSON data
/*    NSDictionary *body = @{@"name": @"camera.listFiles",
                           @"parameters":
                               @{@"fileUrl": fileId,   // ID of file to be acquired
                                 @"_type": @"thumb"}}; // Type of file to be acquired

    // Set the request-body.
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];
*/
    __block NSData *output;

    // Send the url-request.
    NSURLSessionDataTask* task =
    [self->_session dataTaskWithRequest:request
                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                          if (!error) {
                              output = data;
                              NSLog(@"result: %@", response);
                          } else {
                              NSLog(@"error: %@", error);
                          }
                          dispatch_semaphore_signal(semaphore);
                      }];
    [task resume];

    // Wait until signal is called
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return output;
}

/**
 * Acquire storage information of device
 * @return Storage informationget
 */
- (HttpStorageInfo*)getStorageInfo
{
    // Set still image as shooting mode (to acquire size set for still images)
    // Continue session
    [self setOptions:@{@"captureMode":@"image"}];

    // Semaphore for synchronization (cannot be entered until signal is called)
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // Create the url-request.
    NSMutableURLRequest *request = [self createExecuteRequest];

    // Create JSON data
    NSDictionary *body = @{@"name": @"camera.getOptions",
                           @"parameters":
                               @{
                                 @"optionNames":
                                     @[@"remainingPictures",
                                       @"remainingSpace",
                                       @"totalSpace",
                                       @"fileFormat"]}};

    // Set the request-body.
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];

    __block HttpStorageInfo *info = [[HttpStorageInfo alloc] init];

    // Send the url-request.
    NSURLSessionDataTask* task =
        [self->_session dataTaskWithRequest:request
              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                  if (!error) {
                      // Acquire storage information
                      NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                      NSArray *options = [array valueForKeyPath:@"results.options"];
                      info.free_space_in_images = [[options valueForKey:@"remainingPictures"] unsignedLongValue]; // Number of images
                      info.free_space_in_bytes = [[options valueForKey:@"remainingSpace"] unsignedLongValue];     //byte
                      info.max_capacity = [[options valueForKey:@"totalSpace"] unsignedLongValue];                //byte

                      // Acquire file format setting
                      NSArray *fileFormat = [options valueForKey:@"fileFormat"];
                      info.image_width = [[fileFormat valueForKey:@"width"] unsignedLongValue];
                      info.image_height = [[fileFormat valueForKey:@"height"] unsignedLongValue];
                      NSLog(@"result: %@", info);
                  } else {
                      NSLog(@"error: %@", error);
                  }
                  dispatch_semaphore_signal(semaphore);
              }];
    [task resume];

    // Wait until signal is called
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return info;
}

/**
 * Acquire battery information of device
 * @return Battery level (4 levels: 0.0, 0.33, 0.67 and 1.0)
 */
-(NSNumber*)getBatteryLevel
{
    // Semaphore for synchronization (cannot be entered until signal is called)
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // Create the url-request.
    NSMutableURLRequest *request = [self createRequest:@"/osc/state" method:@"POST"];

    __block NSNumber *batteryLevel;

    // Send the url-request.
    NSURLSessionDataTask* task =
    [self->_session dataTaskWithRequest:request
                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                          if (!error) {
                              NSArray* array = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                              NSArray* state = [array valueForKey:@"state"];
                              batteryLevel = [state valueForKey:@"batteryLevel"];
                              NSLog(@"result: %@", batteryLevel);
                          } else {
                              NSLog(@"error: %@", error);
                          }
                          dispatch_semaphore_signal(semaphore);
                      }];
    [task resume];

    // Wait until signal is called
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return batteryLevel;
}

/**
 * Specify shooting size
 * @param width Width of shot image
 * @param height Height of shot image
 */
- (void)setImageFormat:(NSUInteger)width height:(NSUInteger)height
{
    [self setOptions:@{@"captureMode": @"image"}];
    [self setOptions:@{@"fileFormat":
                           @{@"type": @"jpeg",
                             @"width": [NSNumber numberWithUnsignedInteger:width],
                             @"height": [NSNumber numberWithUnsignedInteger:height]}}];
}

/**
 * Start live view
 * @param block Block called on drawing. Used to perform the drawing process of the image.
 */
- (void)startLiveView:(void(^ const)(NSData *frameData))block
{
        NSMutableURLRequest *request = [self createExecuteRequest];
        _stream = [[HttpStream alloc] initWithRequest:request];
        [_stream setDelegate:block];
        [_stream getData];
}

/**
 * Resume live view
 */
- (void)restartLiveView
{
}

/**
 * Take photo<p>
 * After shooting, the status is checked by the timer and the file information is acquired when the status indicates that the process is complete.
 * @return Information on shot media files
 */
- (HttpImageInfo*)takePicture
{
    // Stop live view
    [_stream cancel];

    // Set still image as shooting mode
    // Continue session
    [self setOptions:@{@"captureMode":@"image"}];

    // Semaphore for synchronization (cannot be entered until signal is called)
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // Create the url-request.
    NSMutableURLRequest *request = [self createExecuteRequest];

    // Create JSON data
    NSDictionary *body = @{@"name": @"camera.takePicture"};

    // Set the request-body.
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];

    __block NSString *commandId;

    // Send the url-request.
    NSURLSessionDataTask* task =
    [self->_session dataTaskWithRequest:request
                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                          if (!error) {
                              NSArray* array = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                              commandId = [array valueForKey:@"id"];
                              NSLog(@"commandId: %@", commandId);
                          } else {
                              NSLog(@"error: %@", error);
                          }
                          dispatch_semaphore_signal(semaphore);
                      }];
    [task resume];

    // Wait until signal is called
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    HttpImageInfo *resultInfo = [self waitCommandComplete:commandId];

    // Resume live view
    [_stream getData];

    return resultInfo;
}

/**
 * Check status of specified command and acquire information
 * @param commandId ID of command to be checked
 */
- (HttpImageInfo*)waitCommandComplete:(NSString*)commandId
{
    if (commandId != nil) {
        // Create timer and wait until process is completed
        NSMutableURLRequest *requestForStatus = [self createRequest:@"/osc/commands/status" method:@"POST"];
        HttpStatusTimer *timer = [[HttpStatusTimer alloc] initWithRequest:requestForStatus];
        NSString *status = [timer run:commandId];

        if ([status isEqualToString:@"done"]) {
            // Create the url-request.
            NSMutableURLRequest *requestForList = [self createExecuteRequest];
            HttpFileList *fileList = [[HttpFileList alloc] initWithRequest:requestForList];

            NSUInteger* token;
            do {
                token = [fileList getList:1];
                HttpImageInfo *info = fileList.infoArray.firstObject;
                if ([info.file_id isEqualToString:timer.fileUrl]) {
                    return info;
                }
            } while (token != 0);
        }
    }
    return nil;
}

/**
 * Delete specified file
 * @param info Information of file to be deleted
 * @return Delete process successful?
 */
- (BOOL)deleteImage:(HttpImageInfo*)info
{
    // Semaphore for synchronization (cannot be entered until signal is called)
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // Create the url-request.
    NSMutableURLRequest *request = [self createExecuteRequest];

    // Create JSON data
    NSDictionary *body = @{@"name": @"camera.delete",
                           @"parameters":
                               @{@"fileUri": info.file_id}};

    // Set the request-body.
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];

    __block NSString *status;
    __block NSString *commandId = nil;

    // Send the url-request.
    NSURLSessionDataTask* task =
    [self->_session dataTaskWithRequest:request
                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                          if (!error) {
                              NSArray* array = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                              status = [array valueForKey:@"state"];
                              commandId = [array valueForKey:@"id"];
                              NSLog(@"commandId: %@", commandId);
                          } else {
                              NSLog(@"error: %@", error);
                          }
                          dispatch_semaphore_signal(semaphore);
                      }];
    [task resume];

    // Wait until signal is called
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    if ([status isEqualToString:@"done"]) {
        return YES;
    } else if (commandId != nil) {
        // Create timer and wait until process is completed
        NSMutableURLRequest *requestForStatus = [self createRequest:@"/osc/commands/status" method:@"POST"];
        HttpStatusTimer *timer = [[HttpStatusTimer alloc] initWithRequest:requestForStatus];
        status = [timer run:commandId];
        if ([status isEqualToString:@"done"]) {
            return YES;
        }
    }
    return NO;
}

/**
 * Create HTTP request class instance for executing command
 * @return HTTP request class instance for executing command
 */
- (NSMutableURLRequest*)createExecuteRequest
{
    // Create the url-request.
    return [self createRequest:@"/osc/commands/execute" method:@"POST"];
}


#pragma mark - Private methods.

/**
 * Send option setting request
 * @param options Dictionary in which the option name and settings were configured for the key and value
 */
- (void)setOptions:(NSDictionary*)options
{
    // Semaphore for synchronization (cannot be entered until signal is called)
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // Create the url-request.
    NSMutableURLRequest *request = [self createExecuteRequest];

    // Create JSON data
    NSDictionary *body = @{@"name": @"camera.setOptions",
                           @"parameters":
                               @{
                                 @"options":options}};

    // Set the request-body.
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];

    // Send the url-request.
    NSURLSessionDataTask* task =
    [self->_session dataTaskWithRequest:request
                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                          if (!error) {
                              NSLog(@"result: %@", response);
                          } else {
                              NSLog(@"error: %@", error);
                          }
                          dispatch_semaphore_signal(semaphore);
                      }];
    [task resume];

    // Wait until signal is called
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

/**
 * Create HTTP request
 * @param protocol Path
 * @param method Protocol
 * @return HTTP request instance
 */
- (NSMutableURLRequest*)createRequest:(NSString* const)protocol method:(NSString* const)method
{
    NSString *string = [NSString stringWithFormat:@"http://%@%@", _server, protocol];
    NSURL *url = [NSURL URLWithString:string];

    // Create the url-request.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    // Set the method(HTTP-POST)
    [request setHTTPMethod:method];

    [request setValue:@"application/json; charaset=utf-8" forHTTPHeaderField:@"Content-Type"];

    return request;
}

@end
