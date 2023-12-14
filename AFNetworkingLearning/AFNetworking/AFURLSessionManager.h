//
//  AFURLSessionManager.h
//  AFNetworkingLearning
//
//  Created by cl d on 2023/11/5.
//

#import <Foundation/Foundation.h>
#import "AFURLResponseSerialization.h"

NS_ASSUME_NONNULL_BEGIN

@interface AFURLSessionManager : NSObject<NSURLSessionDelegate,NSURLSessionDataDelegate,NSURLSessionDownloadDelegate,NSCopying>


@property (readonly, nonatomic, strong) NSURLSession *session;

@property (readonly, nonatomic, strong) NSOperationQueue *operationQueue;

@property (nonatomic, strong) id <AFURLResponseSerialization> responseSerializer;


// 初始化方法
- (instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)configuartion NS_DESIGNATED_INITIALIZER;

- (nullable NSProgress *)downloadProgressForTask:(NSURLSessionTask *)task;

- (nullable NSProgress *)uploadProgressForTask:(NSURLSessionTask *)task;


- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                               uploadProgress:(nullable void(^)(NSProgress *uploadProgress))uploadProgressBlock
                             downloadProgress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                            completionHandler:(nullable void (^)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error))completionHandler;

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromFile:(NSURL *)fileURL
                                         progress:(nullable void (^)(NSProgress *uploadPrgress))uploadProgressBlock
                                completionHandler:(nullable void(^)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error))completionHandler;

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromData:(NSData *)bodyData
                                         progress:(nullable void (^)(NSProgress *uploadPrgress))uploadProgressBlock
                                completionHandler:(nullable void(^)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error))completionHandler;

- (NSURLSessionUploadTask *)uploadTaskWithStreamRequest:(NSURLRequest *)request
                                               progress:(nullable void (^)(NSProgress *uploadPrgress))uploadProgressBlock
                                      completionHandler:(nullable void(^)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error))completionHandler;

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request
                                             progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                          destination:(nullable NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                    completionHandler:(nullable void (^)(NSURLResponse *response, NSURL * _Nullable filePath, NSError * _Nullable error))completionHandler;


- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData
                                                progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                             destination:(nullable NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                       completionHandler:(nullable void (^)(NSURLResponse *response, NSURL * _Nullable filePath, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
