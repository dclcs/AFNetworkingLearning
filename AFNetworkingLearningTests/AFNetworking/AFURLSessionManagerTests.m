// AFURLSessionManagerTests.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <objc/runtime.h>

#import "AFTestCase.h"

#import "AFURLSessionManager.h"

#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
#define NSFoundationVersionNumber_With_Fixed_28588583_bug 0.0
#else
#define NSFoundationVersionNumber_With_Fixed_28588583_bug DBL_MAX
#endif


@interface AFURLSessionManagerTests : AFTestCase
@property (readwrite, nonatomic, strong) AFURLSessionManager *localManager;
@property (readwrite, nonatomic, strong) AFURLSessionManager *backgroundManager;
@end

@implementation AFURLSessionManagerTests

- (NSURLRequest *)bigImageURLRequest {
    NSURL *url = [NSURL URLWithString:@"https://scitechdaily.com/images/New-Image-of-the-Galaxy-Messier-94-also-Known-as-NGC-4736.jpg"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    return request;
}

- (void)setUp {
    [super setUp];
    self.localManager = [[AFURLSessionManager alloc] init];
    [self.localManager.session.configuration.URLCache removeAllCachedResponses];

    //It was discovered that background sessions were hanging the test target
    //on iOS 10 and Xcode 8.
    //
    //rdar://28588583
    //
    //For now, we'll disable the unit tests for background managers until that can
    //be resolved
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_With_Fixed_28588583_bug) {
        NSString *identifier = [NSString stringWithFormat:@"com.afnetworking.tests.urlsession.%@", [[NSUUID UUID] UUIDString]];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        self.backgroundManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    }
    else {
        self.backgroundManager = nil;
    }
}

- (void)tearDown {
    [super tearDown];
    [self.localManager.session.configuration.URLCache removeAllCachedResponses];
    [self.localManager invalidateSessionCancelingTasks:YES resetSession:NO];
    self.localManager = nil;
    
    [self.backgroundManager invalidateSessionCancelingTasks:YES resetSession:NO];
    self.backgroundManager = nil;
}

#pragma mark Progress -

- (void)testDataTaskDoesReportDownloadProgress {
    NSURLSessionDataTask *task;

    __weak XCTestExpectation *expectation = [self expectationWithDescription:@"Progress should equal 1.0"];
    task = [self.localManager
            dataTaskWithRequest:[self bigImageURLRequest]
            uploadProgress:nil
            downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                if (downloadProgress.fractionCompleted == 1.0) {
                    [expectation fulfill];
                }
            }
            completionHandler:nil];
    
    [task resume];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testDataTaskDownloadProgressCanBeKVOd {
    NSURLSessionDataTask *task;

    task = [self.localManager
            dataTaskWithRequest:[self bigImageURLRequest]
            uploadProgress:nil
            downloadProgress:nil
            completionHandler:nil];

        NSProgress *progress = [self.localManager downloadProgressForTask:task];
        [self keyValueObservingExpectationForObject:progress keyPath:@"fractionCompleted"
                                            handler:^BOOL(NSProgress  *observedProgress, NSDictionary * _Nonnull change) {
                                                double new = [change[@"new"] doubleValue];
                                                double old = [change[@"old"] doubleValue];
                                                NSLog(@"new = %f old = %f", new, old);
                                                return new == 1.0 && old != 0.0;
                                            }];
    [task resume];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testDownloadTaskDoesReportProgress {
    __weak XCTestExpectation *expectation = [self expectationWithDescription:@"Progress should equal 1.0"];
    NSURLSessionTask *task;
    task = [self.localManager
            downloadTaskWithRequest:[self bigImageURLRequest]
            progress:^(NSProgress * _Nonnull downloadProgress) {
                if (downloadProgress.fractionCompleted == 1.0) {
                    [expectation fulfill];
                }
            }
            destination:nil
            completionHandler:nil];
    [task resume];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testSessionTaskDoesReportMetrics {
    [self expectationForNotification:AFNetworkingTaskDidCompleteNotification object:nil handler:^BOOL(NSNotification * _Nonnull notification) {
#if AF_CAN_USE_AT_AVAILABLE && AF_CAN_INCLUDE_SESSION_TASK_METRICS
        if (@available(iOS 10, macOS 10.12, watchOS 3, tvOS 10, *)) {
            return [notification userInfo][AFNetworkingTaskDidCompleteSessionTaskMetrics] != nil;
        }
#endif
        return YES;
    }];

#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
    __weak XCTestExpectation *metricsBlock = [self expectationWithDescription:@"Metrics completion block is called"];
    [self.localManager setTaskDidFinishCollectingMetricsBlock:^(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLSessionTaskMetrics * _Nullable metrics) {
        [metricsBlock fulfill];
    }];
#endif

    NSURLSessionTask *task = [self.localManager downloadTaskWithRequest:[self bigImageURLRequest]
                                                               progress:nil
                                                            destination:nil
                                                      completionHandler:nil];
    [task resume];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testSessionIsStillValid {
    
    NSURLSession *session = self.localManager.session;
    [self.localManager invalidateSessionCancelingTasks:YES resetSession:NO];
    
    XCTAssertEqual(session, self.localManager.session);
}

- (void)testSessionRecreatesAgain {
    
    [self.localManager invalidateSessionCancelingTasks:YES resetSession:YES];
    
    XCTAssertNotNil(self.localManager.session);
}

- (void)testUploadTaskDoesReportProgress {
    NSMutableString *payload = [NSMutableString stringWithString:@"AFNetworking"];
    while ([payload lengthOfBytesUsingEncoding:NSUTF8StringEncoding] < 20000) {
        [payload appendString:@"AFNetworking"];
    }

    NSURL *url = [NSURL URLWithString:[[self.baseURL absoluteString] stringByAppendingString:@"/post"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    [request setHTTPMethod:@"POST"];

    __weak XCTestExpectation *expectation = [self expectationWithDescription:@"Progress should equal 1.0"];

    NSURLSessionTask *task;
    task = [self.localManager
            uploadTaskWithRequest:request
            fromData:[payload dataUsingEncoding:NSUTF8StringEncoding]
            progress:^(NSProgress * _Nonnull uploadProgress) {
                NSLog(@"%@", uploadProgress.localizedDescription);
                if (uploadProgress.fractionCompleted == 1.0) {
                    [expectation fulfill];
                }
            }
            completionHandler:nil];
    [task resume];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testUploadProgressCanBeKVOd {
    NSMutableString *payload = [NSMutableString stringWithString:@"AFNetworking"];
    while ([payload lengthOfBytesUsingEncoding:NSUTF8StringEncoding] < 20000) {
        [payload appendString:@"AFNetworking"];
    }

    NSURL *url = [NSURL URLWithString:[[self.baseURL absoluteString] stringByAppendingString:@"/post"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    [request setHTTPMethod:@"POST"];

    NSURLSessionTask *task;
    task = [self.localManager
            uploadTaskWithRequest:request
            fromData:[payload dataUsingEncoding:NSUTF8StringEncoding]
            progress:nil
            completionHandler:nil];

    NSProgress *uploadProgress = [self.localManager uploadProgressForTask:task];
    [self keyValueObservingExpectationForObject:uploadProgress keyPath:NSStringFromSelector(@selector(fractionCompleted)) expectedValue:@(1.0)];

    [task resume];
    [self waitForExpectationsWithCommonTimeout];
}

#pragma mark - Issue #2702 Tests
// The following tests are all releated to issue #2702

- (void)testDidResumeNotificationIsReceivedByLocalDataTaskAfterResume {
    NSURLSessionDataTask *task = [self.localManager dataTaskWithRequest:[self _delayURLRequest]
                                                         uploadProgress:nil
                                                       downloadProgress:nil
                                                      completionHandler:nil];
    [self _testResumeNotificationForTask:task];
}

- (void)testDidSuspendNotificationIsReceivedByLocalDataTaskAfterSuspend {
    NSURLSessionDataTask *task = [self.localManager dataTaskWithRequest:[self _delayURLRequest]
                                                         uploadProgress:nil
                                                       downloadProgress:nil
                                                      completionHandler:nil];
    [self _testSuspendNotificationForTask:task];
}

- (void)testDidResumeNotificationIsReceivedByBackgroundDataTaskAfterResume {
    if (self.backgroundManager) {
        NSURLSessionDataTask *task = [self.backgroundManager dataTaskWithRequest:[self _delayURLRequest]
                                                                  uploadProgress:nil
                                                                downloadProgress:nil
                                                               completionHandler:nil];
        [self _testResumeNotificationForTask:task];
    }
}

- (void)testDidSuspendNotificationIsReceivedByBackgroundDataTaskAfterSuspend {
    if (self.backgroundManager) {
        NSURLSessionDataTask *task = [self.backgroundManager dataTaskWithRequest:[self _delayURLRequest]
                                                                  uploadProgress:nil
                                                                downloadProgress:nil
                                                               completionHandler:nil];
        [self _testSuspendNotificationForTask:task];
    }
}

- (void)testDidResumeNotificationIsReceivedByLocalUploadTaskAfterResume {
    NSURLSessionUploadTask *task = [self.localManager uploadTaskWithRequest:[self _delayURLRequest]
                                                                   fromData:[NSData data]
                                                                   progress:nil
                                                          completionHandler:nil];
    [self _testResumeNotificationForTask:task];
}

- (void)testDidSuspendNotificationIsReceivedByLocalUploadTaskAfterSuspend {
    NSURLSessionUploadTask *task = [self.localManager uploadTaskWithRequest:[self _delayURLRequest]
                                                                   fromData:[NSData data]
                                                                   progress:nil
                                                          completionHandler:nil];
    [self _testSuspendNotificationForTask:task];
}

- (void)testDidResumeNotificationIsReceivedByBackgroundUploadTaskAfterResume {
    if (self.backgroundManager) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnonnull"
        NSURLSessionUploadTask *task = [self.backgroundManager uploadTaskWithRequest:[self _delayURLRequest]
                                                                            fromFile:nil
                                                                            progress:nil
                                                                   completionHandler:nil];
#pragma clang diagnostic pop
        [self _testResumeNotificationForTask:task];
    }
}

- (void)testDidSuspendNotificationIsReceivedByBackgroundUploadTaskAfterSuspend {
    if (self.backgroundManager) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnonnull"
        NSURLSessionUploadTask *task = [self.backgroundManager uploadTaskWithRequest:[self _delayURLRequest]
                                                                            fromFile:nil
                                                                            progress:nil
                                                                   completionHandler:nil];
#pragma clang diagnostic pop
        [self _testSuspendNotificationForTask:task];
    }
}

- (void)testDidResumeNotificationIsReceivedByLocalDownloadTaskAfterResume {
    NSURLSessionDownloadTask *task = [self.localManager downloadTaskWithRequest:[self _delayURLRequest]
                                                                progress:nil
                                                             destination:nil
                                                       completionHandler:nil];
    [self _testResumeNotificationForTask:task];
}

- (void)testDidSuspendNotificationIsReceivedByLocalDownloadTaskAfterSuspend {
    NSURLSessionDownloadTask *task = [self.localManager downloadTaskWithRequest:[self _delayURLRequest]
                                                                progress:nil
                                                             destination:nil
                                                       completionHandler:nil];
    [self _testSuspendNotificationForTask:task];
}

- (void)testDidResumeNotificationIsReceivedByBackgroundDownloadTaskAfterResume {
    if (self.backgroundManager) {
        NSURLSessionDownloadTask *task = [self.backgroundManager downloadTaskWithRequest:[self _delayURLRequest]
                                                                                progress:nil
                                                                             destination:nil
                                                                       completionHandler:nil];
        [self _testResumeNotificationForTask:task];
    }
}

- (void)testDidSuspendNotificationIsReceivedByBackgroundDownloadTaskAfterSuspend {
    if (self.backgroundManager) {
        NSURLSessionDownloadTask *task = [self.backgroundManager downloadTaskWithRequest:[self _delayURLRequest]
                                                                                progress:nil
                                                                             destination:nil
                                                                       completionHandler:nil];
        [self _testSuspendNotificationForTask:task];
    }
}

- (void)testSwizzlingIsProperlyConfiguredForDummyClass {
    IMP originalAFResumeIMP = [self _originalAFResumeImplementation];
    IMP originalAFSuspendIMP = [self _originalAFSuspendImplementation];
    XCTAssert(originalAFResumeIMP, @"Swizzled af_resume Method Not Found");
    XCTAssert(originalAFSuspendIMP, @"Swizzled af_suspend Method Not Found");
    XCTAssertNotEqual(originalAFResumeIMP, originalAFSuspendIMP, @"af_resume and af_suspend should not be equal");
}

- (void)testSwizzlingIsWorkingAsExpectedForForegroundDataTask {
    NSURLSessionTask *task = [self.localManager dataTaskWithRequest:[self _delayURLRequest]
                                                     uploadProgress:nil
                                                   downloadProgress:nil
                                                  completionHandler:nil];
    [self _testSwizzlingForTask:task];
    [task cancel];
}

- (void)testSwizzlingIsWorkingAsExpectedForForegroundUpload {
    NSURLSessionTask *task = [self.localManager uploadTaskWithRequest:[self _delayURLRequest]
                                                        fromData:[NSData data]
                                                        progress:nil
                                               completionHandler:nil];
    [self _testSwizzlingForTask:task];
    [task cancel];
}

- (void)testSwizzlingIsWorkingAsExpectedForForegroundDownload {
    NSURLSessionTask *task = [self.localManager downloadTaskWithRequest:[self _delayURLRequest]
                                                          progress:nil
                                                       destination:nil
                                                 completionHandler:nil];
    [self _testSwizzlingForTask:task];
    [task cancel];
}

- (void)testSwizzlingIsWorkingAsExpectedForBackgroundDataTask {
    //iOS 7 doesn't let us use a background manager in these tests, so reference these
    //classes directly. There are tests below to confirm background manager continues
    //to return the exepcted classes going forward. If those fail in a future iOS version,
    //it should point us to a problem here.
    [self _testSwizzlingForTaskClass:NSClassFromString(@"__NSCFBackgroundDataTask")];
}

- (void)testSwizzlingIsWorkingAsExpectedForBackgroundUploadTask {
    //iOS 7 doesn't let us use a background manager in these tests, so reference these
    //classes directly. There are tests below to confirm background manager continues
    //to return the exepcted classes going forward. If those fail in a future iOS version,
    //it should point us to a problem here.
    [self _testSwizzlingForTaskClass:NSClassFromString(@"__NSCFBackgroundUploadTask")];
}

- (void)testSwizzlingIsWorkingAsExpectedForBackgroundDownloadTask {
    //iOS 7 doesn't let us use a background manager in these tests, so reference these
    //classes directly. There are tests below to confirm background manager continues
    //to return the exepcted classes going forward. If those fail in a future iOS version,
    //it should point us to a problem here.
    [self _testSwizzlingForTaskClass:NSClassFromString(@"__NSCFBackgroundDownloadTask")];
}

- (void)testBackgroundManagerReturnsExpectedClassForDataTask {
    if (self.backgroundManager) {
        NSURLSessionTask *task = [self.backgroundManager dataTaskWithRequest:[self _delayURLRequest]
                                                              uploadProgress:nil
                                                            downloadProgress:nil
                                                           completionHandler:nil];
        XCTAssert([NSStringFromClass([task class]) isEqualToString:@"__NSCFBackgroundDataTask"]);
        [task cancel];
    } else {
        NSLog(@"Unable to run %@ because self.backgroundManager is nil", NSStringFromSelector(_cmd));
    }
}

- (void)testBackgroundManagerReturnsExpectedClassForUploadTask {
    if (self.backgroundManager) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnonnull"
        NSURLSessionTask *task = [self.backgroundManager uploadTaskWithRequest:[self _delayURLRequest]
                                                                      fromFile:nil
                                                                      progress:nil
                                                             completionHandler:nil];
#pragma clang diagnostic pop
        XCTAssert([NSStringFromClass([task class]) isEqualToString:@"__NSCFBackgroundUploadTask"]);
        [task cancel];
    } else {
        NSLog(@"Unable to run %@ because self.backgroundManager is nil", NSStringFromSelector(_cmd));
    }
}

- (void)testBackgroundManagerReturnsExpectedClassForDownloadTask {
    if (self.backgroundManager) {
        NSURLSessionTask *task = [self.backgroundManager downloadTaskWithRequest:[self _delayURLRequest]
                                                                        progress:nil
                                                                     destination:nil
                                                               completionHandler:nil];
        XCTAssert([NSStringFromClass([task class]) isEqualToString:@"__NSCFBackgroundDownloadTask"]);
        [task cancel];
    } else {
        NSLog(@"Unable to run %@ because self.backgroundManager is nil", NSStringFromSelector(_cmd));
    }
}

#pragma mark - Notifications

- (void)testTaskMoveSuccessfullyAfterDownloading {
    NSURL *dirURL = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *destinationURL = [dirURL URLByAppendingPathComponent:NSUUID.UUID.UUIDString];

    NSURLSessionDownloadTask *task = [self.localManager downloadTaskWithRequest:[self bigImageURLRequest]
                progress:nil
             destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
                return destinationURL;
            }
       completionHandler:nil];

    [self expectationForNotification:AFURLSessionDownloadTaskDidMoveFileSuccessfullyNotification
                              object:nil
                             handler:nil];
    [task resume];
    [self waitForExpectationsWithCommonTimeout];
    [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
}

- (void)testTaskMoveFailedAfterDownloading {
    NSURLSessionDownloadTask *downloadTask = [self.localManager downloadTaskWithRequest:[self bigImageURLRequest]
               progress:nil
            destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
                // Try to move the destination file to a nonexist path on purpose for simulating a move failure.
                return [NSURL fileURLWithPath:@"/a/b/c"];
            }
      completionHandler:nil];

    [self expectationForNotification:AFURLSessionDownloadTaskDidFailToMoveFileNotification
                              object:nil
                             handler:nil];
    [downloadTask resume];
    [self waitForExpectationsWithCommonTimeout];
}

#pragma mark - private

- (void)_testResumeNotificationForTask:(NSURLSessionTask *)task {
    [self expectationForNotification:AFNetworkingTaskDidResumeNotification
                              object:nil
                             handler:nil];
    [task resume];
    [task suspend];
    [task resume];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [task cancel];
}

- (void)_testSuspendNotificationForTask:(NSURLSessionTask *)task {
    [self expectationForNotification:AFNetworkingTaskDidSuspendNotification
                              object:nil
                             handler:nil];
    [task resume];
    [task suspend];
    [task resume];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [task cancel];
}

- (NSURLRequest *)_delayURLRequest {
    return [NSURLRequest requestWithURL:self.delayURL];
}

- (IMP)_implementationForTask:(NSURLSessionTask *)task selector:(SEL)selector {
    return [self _implementationForClass:[task class] selector:selector];
}

- (IMP)_implementationForClass:(Class)class selector:(SEL)selector {
    return method_getImplementation(class_getInstanceMethod(class, selector));
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
- (IMP)_originalAFResumeImplementation {
    return method_getImplementation(class_getInstanceMethod(NSClassFromString(@"_AFURLSessionTaskSwizzling"), @selector(af_resume)));
}

- (IMP)_originalAFSuspendImplementation {
    return method_getImplementation(class_getInstanceMethod(NSClassFromString(@"_AFURLSessionTaskSwizzling"), @selector(af_suspend)));
}

- (void)_testSwizzlingForTask:(NSURLSessionTask *)task {
    [self _testSwizzlingForTaskClass:[task class]];
}

- (void)_testSwizzlingForTaskClass:(Class)class {
    IMP originalAFResumeIMP = [self _originalAFResumeImplementation];
    IMP originalAFSuspendIMP = [self _originalAFSuspendImplementation];
    
    IMP taskResumeImp = [self _implementationForClass:class selector:@selector(resume)];
    IMP taskSuspendImp = [self _implementationForClass:class selector:@selector(suspend)];
    XCTAssertEqual(originalAFResumeIMP, taskResumeImp, @"resume has not been properly swizzled for %@", NSStringFromClass(class));
    XCTAssertEqual(originalAFSuspendIMP, taskSuspendImp, @"suspend has not been properly swizzled for %@", NSStringFromClass(class));
    
    IMP taskAFResumeImp = [self _implementationForClass:class selector:@selector(af_resume)];
    IMP taskAFSuspendImp = [self _implementationForClass:class selector:@selector(af_suspend)];
    XCTAssert(taskAFResumeImp != NULL, @"af_resume is nil. Something has not been been swizzled right for %@", NSStringFromClass(class));
    XCTAssertNotEqual(taskAFResumeImp, taskResumeImp, @"af_resume has not been properly swizzled for %@", NSStringFromClass(class));
    XCTAssert(taskAFSuspendImp != NULL, @"af_suspend is nil. Something has not been been swizzled right for %@", NSStringFromClass(class));
    XCTAssertNotEqual(taskAFSuspendImp, taskSuspendImp, @"af_suspend has not been properly swizzled for %@", NSStringFromClass(class));
}
#pragma clang diagnostic pop

@end
