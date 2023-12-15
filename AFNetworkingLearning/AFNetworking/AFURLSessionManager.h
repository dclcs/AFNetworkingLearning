//
//  AFURLSessionManager.h
//  AFNetworkingLearning
//
//  Created by cl d on 2023/11/5.
//

#import <Foundation/Foundation.h>
#import "AFURLResponseSerialization.h"

NS_ASSUME_NONNULL_BEGIN


FOUNDATION_EXPORT NSString * const AFNetworkingTaskDidResumeNotification;

FOUNDATION_EXPORT NSString * const AFNetworkingTaskDidCompleteNotification;

FOUNDATION_EXPORT NSString * const AFNetworkingTaskDidSuspendNotification;

/**
 Posted when a session is invalidated.
 */
FOUNDATION_EXPORT NSString * const AFURLSessionDidInvalidateNotification;

/**
 Posted when a session download task finished moving the temporary download file to a specified destination successfully.
 */
FOUNDATION_EXPORT NSString * const AFURLSessionDownloadTaskDidMoveFileSuccessfullyNotification;

/**
 Posted when a session download task encountered an error when moving the temporary download file to a specified destination.
 */
FOUNDATION_EXPORT NSString * const AFURLSessionDownloadTaskDidFailToMoveFileNotification;

/**
 The raw response data of the task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if response data exists for the task.
 */
FOUNDATION_EXPORT NSString * const AFNetworkingTaskDidCompleteResponseDataKey;

/**
 The serialized response object of the task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if the response was serialized.
 */
FOUNDATION_EXPORT NSString * const AFNetworkingTaskDidCompleteSerializedResponseKey;

/**
 The response serializer used to serialize the response. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if the task has an associated response serializer.
 */
FOUNDATION_EXPORT NSString * const AFNetworkingTaskDidCompleteResponseSerializerKey;

/**
 The file path associated with the download task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if an the response data has been stored directly to disk.
 */
FOUNDATION_EXPORT NSString * const AFNetworkingTaskDidCompleteAssetPathKey;

/**
 Any error associated with the task, or the serialization of the response. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if an error exists.
 */
FOUNDATION_EXPORT NSString * const AFNetworkingTaskDidCompleteErrorKey;

/**
 The session task metrics taken from the download task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteSessionTaskMetrics`
 */
FOUNDATION_EXPORT NSString * const AFNetworkingTaskDidCompleteSessionTaskMetrics;

@interface AFURLSessionManager : NSObject<NSURLSessionDelegate,NSURLSessionTaskDelegate, NSURLSessionDataDelegate,NSURLSessionDownloadDelegate,NSCopying>


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


- (void)invalidateSessionCancelingTasks:(BOOL)cancelPendingTasks resetSession:(BOOL)resetSession;


@end

NS_ASSUME_NONNULL_END
