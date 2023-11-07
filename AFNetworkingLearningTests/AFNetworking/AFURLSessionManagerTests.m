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
        NSLog(@"123132");
        [exception fulfill];
    }];
    
    [task resume];
    [self waitForExpectationsWithCommonTimeout];
}
@end
