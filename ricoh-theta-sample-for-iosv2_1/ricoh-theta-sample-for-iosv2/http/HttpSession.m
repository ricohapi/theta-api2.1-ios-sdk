/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "HttpSession.h"

/**
 * File download class
 */
@interface HttpSession() <NSURLSessionDownloadDelegate>
{
    NSMutableURLRequest* _request;
    NSURLSession *_session;
    void (^onStart)(int64_t expectedTotalBytes);
    void (^onWrite)(int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite);
    void (^onFinish)(NSURL *location);
}
@end

@implementation HttpSession

/**
 * Specified initializer
 * @param request HTTP request
 * @return Instance
 */
- (id)initWithRequest:(NSMutableURLRequest*)request
{
    if (self = [super init]) {
        self->_request = request;
    }
    return self;
}

/**
 * Download file with specified file ID
 * @param fileUri ID of file to be downloaded
 * @param startBlock Block to be called on start of download
 * @param writeBlock Blocks to be called successively during download
 * @param finishBlock Block to be called at end of download
 */
-(void)getResizedImageObject:(NSString*)fileUrl
                     onStart:(void(^)(int64_t expectedTotalBytes))startBlock
                     onWrite:(void(^)(int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite))writeBlock
                    onFinish:(void(^)(NSURL *location))finishBlock;

{
    self->onStart = startBlock;
    self->onWrite = writeBlock;
    self->onFinish = finishBlock;
    
    // Create the url-request.
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    if(fileUrl != NULL){
        NSURL *url = [NSURL URLWithString:fileUrl];
        
        // Create the url-request.
        request = [NSMutableURLRequest requestWithURL:url];
        
        // Set the method(HTTP-POST)
        [request setHTTPMethod:@"GET"];
    }
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    
    // Download data as file
    NSURLSessionDownloadTask* task = [_session downloadTaskWithRequest:self->_request];
    
    [task resume];
}

/**
 * Delegate to be called on start of download
 * @param session Session
 * @param downloadTask Task
 * @param fileOffset Acquired byte count on disk
 * @param expectedTotalBytes Predicted byte count of entire acquired file
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    NSLog(@"expectedTotalBytes: %lld", expectedTotalBytes);
    self->onStart(expectedTotalBytes);
}

/**
 * Delegates to be called successively during download
 * @param session Session
 * @param downloadTask Task
 * @param bytesWritten Byte count transferred each time a delegate method is called
 * @param totalBytesWritten Current total transferred byte count
 * @param totalBytesExpectedToWrite Predicted byte count of acquired file
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    self->onWrite(totalBytesWritten, totalBytesExpectedToWrite);
}

/**
 * Delegate to be called at end of download
 * @param session Session
 * @param downloadTask Task
 * @param location File URL of acquired temporary file
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    self->onFinish(location);
}
@end
