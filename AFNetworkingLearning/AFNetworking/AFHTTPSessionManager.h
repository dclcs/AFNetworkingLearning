//
//  AFHTTPSessionManager.h
//  AFNetworkingLearning
//
//  Created by cl d on 2023/11/5.
//

#import <Foundation/Foundation.h>
#import "AFURLSessionManager.h"
#import "AFURLRequestSerialization.h"

NS_ASSUME_NONNULL_BEGIN

@interface AFHTTPSessionManager : AFURLSessionManager <NSSecureCoding, NSCopying>

@property (readonly, nonatomic, strong, nullable) NSURL *baseURL;

@property (nonatomic, strong) AFHTTPRequestSerializer <AFURLRequestSerialization> * requestSerializer;

+ (instancetype)manager;

- (instancetype)initWithBaseURL:(nullable NSURL *)url;

- (instancetype)initWithBaseURL:(nullable NSURL *)url
           sessionConfiguration:(nullable NSURLSessionConfiguration *)configuratiion NS_DESIGNATED_INITIALIZER;

- (nullable NSURLSessionDataTask *)GET:(NSString *)URLString
                            parameters:(nullable id)parameters
                               headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                              progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgress
                               success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                               failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error))failure;



- (nullable NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                                                URLString:(NSString *)URLString
                                               parameters:(nullable id)parameters
                                                  headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                                           uploadProgress:(nullable void (^)(NSProgress *uploadProgress))uploadProgress
                                         downloadProgress:(nullable void (^)(NSProgress *downloadProgress))downloadProgress
                                                  success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                                                  failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error))failure;
@end

NS_ASSUME_NONNULL_END
