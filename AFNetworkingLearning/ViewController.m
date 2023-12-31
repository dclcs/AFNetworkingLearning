//
//  ViewController.m
//  AFNetworkingLearning
//
//  Created by cl d on 2023/11/5.
//

#import "ViewController.h"
#import "AFURLSessionManager.h"
#import "AFNetworking/AFHTTPSessionManager.h"
@interface ViewController ()
@property (readwrite, nonatomic, strong) AFURLSessionManager *localManager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.localManager = [[AFURLSessionManager alloc] init];
    [self.localManager.session.configuration.URLCache removeAllCachedResponses];
    [[AFHTTPSessionManager manager] GET:@"https://www.baidu.com" parameters:nil headers:nil progress:nil success:nil failure:nil];
    NSURLSessionTask *task = [self.localManager dataTaskWithRequest:[self bigImageURLRequest]
                                   uploadProgress:nil
                                 downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
        if (downloadProgress.fractionCompleted == 1.0) {

        }
    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {

    }];
    [task resume];
}

- (NSURLRequest *)bigImageURLRequest {
    NSURL *url = [NSURL URLWithString:@"https://scitechdaily.com/images/New-Image-of-the-Galaxy-Messier-94-also-Known-as-NGC-4736.jpg"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    return request;
}


@end
