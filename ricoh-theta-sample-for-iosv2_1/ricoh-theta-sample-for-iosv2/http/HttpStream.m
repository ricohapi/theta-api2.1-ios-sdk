/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "HttpStream.h"

// Start and end markers for images in JPEG format
const Byte SOI_MARKER[] = {0xFF, 0xD8};
const Byte EOI_MARKER[] = {0xFF, 0xD9};

/**
 * Live view data acquisition class
 */
@interface HttpStream() <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
{
    NSMutableURLRequest *_request;
    NSMutableData *_buffer;
    NSMutableArray *_frameArray;
    NSURLSessionDataTask *_task;
    void (^_onBuffered)(NSData *frameData);
    BOOL _isContinue;
}
@end

@implementation HttpStream

/**
 * Set block to be executed when receiving data
 * @param bufferBlock Block to be executed when receiving data
 */
- (void)setDelegate:(void(^)(NSData *frameData))bufferBlock
{
    _onBuffered = bufferBlock;
}

/**
 * Specified initializer
 * @param request HTTP request
 * @return Instance
 */
- (id)initWithRequest:(NSMutableURLRequest*)request 
{
    if (self = [super init]) {
        _request = request;
        _buffer = [NSMutableData data];
        _frameArray = [NSMutableArray array];
        _isContinue = NO;
    }
    return self;
}

/**
 * Start data acquisition
 */
- (void)getData
{
    if (!_isContinue) {
        // Create JSON data
        NSDictionary *body = @{@"name": @"camera.getLivePreview"};
        
        // Set the request-body.
        [self->_request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];
        
        NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession* session = [NSURLSession sessionWithConfiguration:config
                                                              delegate:self
                                                         delegateQueue:[NSOperationQueue mainQueue]];
        
        // Start data acquisition task
        _task = [session dataTaskWithRequest:_request];
        [_task resume];
        _isContinue = YES;
    }
}

/**
 * Stop data acquisition task
 */
- (void)cancel
{
    [_task cancel];
}

/**
 * Delegate for notification that part of the data has been received by the data acquisition task
 * @param session Session
 * @param dataTask Task
 * @param data Received data
 */
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    [_buffer appendData:data];
    Byte b1[2];

    // Search for SOI marker position from buffer
    NSUInteger soi;
    NSUInteger eoi;
    do {
        soi = 0;
        eoi = 0;
        NSInteger i = 0;
    
        for (; i < (NSInteger)_buffer.length - 1; i++) {
            [_buffer getBytes:b1 range:NSMakeRange(i, 2)];
            if (SOI_MARKER[0] == b1[0]) {
                if (SOI_MARKER[1] == b1[1]) {
                    soi = i;
                    break;
                }
            }
        }

        for (; i < (NSInteger)_buffer.length - 1; i++) {
            [_buffer getBytes:b1 range:NSMakeRange(i, 2)];
            if (EOI_MARKER[0] == b1[0]) {
                if (EOI_MARKER[1] == b1[1]) {
                    eoi = i;
                    break;
                }
            }
        }

        // Exit process if EOI not found
        if (eoi == 0) {
            return;
        }
        NSData *frameData = [_buffer subdataWithRange:NSMakeRange(soi, eoi - soi)];

        // Draw
        _onBuffered(frameData);
            
        // Delete used parts of data
        NSUInteger remainLength = _buffer.length - eoi - 2;
        Byte remain[remainLength];
        [_buffer getBytes:remain range:NSMakeRange(eoi + 2, remainLength)];
        _buffer = [NSMutableData dataWithBytes:remain length:remainLength];
    } while (0 < eoi);
}

/**
 * Delegate for notification that the data task has finished receiving data
 * @param session Session
 * @param task Task
 * @param error Error information
 */
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    // Called when session expires
    [session invalidateAndCancel];
    _isContinue = NO;
    NSLog(@"HttpStream didCompleteWithError: %@", error);
}

@end
