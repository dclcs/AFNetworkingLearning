//
//  AFURLSessionManagerTests.m
//  AFNetworkingLearningTests
//
//  Created by dcl on 2023/11/6.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "AFTestCase.h"
#import "AFURLSessionManager.h"
@interface AFURLSessionManagerTests : AFTestCase
@property (readwrite, nonatomic, strong) AFURLSessionManager *localManager;
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
}

- (void)tearDown {
    [super tearDown];
    [self.localManager.session.configuration.URLCache removeAllCachedResponses];
}


#pragma mark Progress -
- (void)testDataTaskDoesReportDownloadProgress
{
    NSURLSessionTask *task;
    
    __weak XCTestExpectation *exception = [self expectationWithDescription:@"Progress should equal 1.0"];
    task = [self.localManager dataTaskWithRequest:[self bigImageURLRequest] 
                                   uploadProgress:nil
                                 downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
        if (downloadProgress.fractionCompleted == 1.0) {
            [exception fulfill];
        }
    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (!error) {
            [exception fulfill];
        }
    }];
    
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
@end
