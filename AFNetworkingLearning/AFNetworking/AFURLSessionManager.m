//
//  AFURLSessionManager.m
//  AFNetworkingLearning
//
//  Created by cl d on 2023/11/5.
//

#import "AFURLSessionManager.h"
#import <objc/runtime.h>


static dispatch_queue_t url_session_manager_processing_queue(void) {
    static dispatch_queue_t af_url_session_manager_processing_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_url_session_manager_processing_queue = dispatch_queue_create("com.alamofire.networking.session.manager.processing", DISPATCH_QUEUE_CONCURRENT);
    });

    return af_url_session_manager_processing_queue;
}

static dispatch_group_t url_session_manager_completion_group(void)
{
    static dispatch_group_t af_url_session_manager_completion_group;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_url_session_manager_completion_group = dispatch_group_create();
    });
    
    return af_url_session_manager_completion_group;
}

NSString * const AFNetworkingTaskDidResumeNotification = @"com.alamofire.networking.task.resume";
NSString * const AFNetworkingTaskDidCompleteNotification = @"com.alamofire.networking.task.complete";
NSString * const AFNetworkingTaskDidSuspendNotification = @"com.alamofire.networking.task.suspend";
NSString * const AFURLSessionDidInvalidateNotification = @"com.alamofire.networking.session.invalidate";
NSString * const AFURLSessionDownloadTaskDidMoveFileSuccessfullyNotification = @"com.alamofire.networking.session.download.file-manager-succeed";
NSString * const AFURLSessionDownloadTaskDidFailToMoveFileNotification = @"com.alamofire.networking.session.download.file-manager-error";

NSString * const AFNetworkingTaskDidCompleteSerializedResponseKey = @"com.alamofire.networking.task.complete.serializedresponse";
NSString * const AFNetworkingTaskDidCompleteResponseSerializerKey = @"com.alamofire.networking.task.complete.responseserializer";
NSString * const AFNetworkingTaskDidCompleteResponseDataKey = @"com.alamofire.networking.complete.finish.responsedata";
NSString * const AFNetworkingTaskDidCompleteErrorKey = @"com.alamofire.networking.task.complete.error";
NSString * const AFNetworkingTaskDidCompleteAssetPathKey = @"com.alamofire.networking.task.complete.assetpath";
NSString * const AFNetworkingTaskDidCompleteSessionTaskMetrics = @"com.alamofire.networking.complete.sessiontaskmetrics";


static NSString * const AFURLSessionManagerLockName = @"com.alamofire.networking.session.manager.lock";
static NSString * const AFNSURLSessionTaskDidResumeNotification  = @"com.alamofire.networking.nsurlsessiontask.resume";
static NSString * const AFNSURLSessionTaskDidSuspendNotification = @"com.alamofire.networking.nsurlsessiontask.suspend";
typedef NSURL * (^AFURLSessionDownloadTaskDidFinishDownloadingBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location);
typedef void (^AFURLSessionDownloadTaskDidWriteDataBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite);
typedef void (^AFURLSessionDownloadTaskDidResumeBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t fileOffset, int64_t expectedTotalBytes);
typedef void (^AFURLSessionTaskProgressBlock)(NSProgress *);

typedef void (^AFURLSessionTaskCompletionHandler)(NSURLResponse *response, id responseObject, NSError *error);

typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential);


typedef NSURLRequest * (^AFURLSessionTaskWillPerformHTTPRedirectionBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request);
typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionTaskDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential);
typedef id (^AFURLSessionTaskAuthenticationChallengeBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, void (^completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential));
typedef void (^AFURLSessionDidFinishEventsForBackgroundURLSessionBlock)(NSURLSession *session);

typedef NSInputStream * (^AFURLSessionTaskNeedNewBodyStreamBlock)(NSURLSession *session, NSURLSessionTask *task);
typedef void (^AFURLSessionTaskDidSendBodyDataBlock)(NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend);
typedef void (^AFURLSessionTaskDidCompleteBlock)(NSURLSession *session, NSURLSessionTask *task, NSError *error);

static inline void af_swizzleSelector(Class theClass, SEL originalSelector, SEL swizzleSeletor)
{
    Method originalMethod = class_getInstanceMethod(theClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(theClass, swizzleSeletor);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

static inline BOOL af_addMethod(Class theClass, SEL selector, Method method)
{
    return class_addMethod(theClass, selector, method_getImplementation(method), method_getTypeEncoding(method));
}

@interface _AFURLSessionTaskSwizzling : NSObject

@end

@implementation _AFURLSessionTaskSwizzling

+ (void)load
{
    if (NSClassFromString(@"NSURLSessionTask")) {
        NSLog(@"_AFURLSessionTaskSwizzling");
        NSURLSessionConfiguration *configuartion = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuartion];
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnonnull"
        NSURLSessionDataTask *localDataTask = [session dataTaskWithURL:nil];
#pragma clang diagnostic pop
        IMP originalAFResumeIMP = method_getImplementation(class_getInstanceMethod([self class], @selector(af_resume)));
        Class currentClass = [localDataTask class];
        
        while (class_getInstanceMethod(currentClass, @selector(resume))) {
            Class superClass = [currentClass superclass];
            IMP classResumeIMP = method_getImplementation(class_getInstanceMethod(currentClass, @selector(resume)));
            IMP superClassResumeIMP = method_getImplementation(class_getInstanceMethod(superClass, @selector(resume)));
            if (classResumeIMP != superClassResumeIMP && originalAFResumeIMP != classResumeIMP) {
                [self swizzleResumeAndSuspendMethodForClass:currentClass];
            }
            currentClass = [currentClass superclass];
        }
        [localDataTask cancel];
        [session finishTasksAndInvalidate];
    }
}


+ (void)swizzleResumeAndSuspendMethodForClass:(Class)theClass
{
    Method afResumeMethod = class_getInstanceMethod(self, @selector(af_resume));
    Method afSuspendMethod = class_getInstanceMethod(self, @selector(af_suspend));
    
    if (af_addMethod(theClass, @selector(af_resume), afResumeMethod)) {
        af_swizzleSelector(theClass, @selector(resume), @selector(af_resume));
    }
    
    if (af_addMethod(theClass, @selector(af_suspend), afSuspendMethod)) {
        af_swizzleSelector(theClass, @selector(suspend), @selector(af_suspend));
    }
}

- (NSURLSessionTaskState)state {
    NSAssert(NO, @"State Method should be claaed in the actual dummy class");
    return NSURLSessionTaskStateCanceling;
}

- (void)af_resume {
    NSAssert([self respondsToSelector:@selector(state)], @"Does not respond to state");
    NSURLSessionTaskState state = [self state];
    [self af_resume];
    
    if (state != NSURLSessionTaskStateRunning) {
        [[NSNotificationCenter defaultCenter] postNotificationName:AFNSURLSessionTaskDidResumeNotification object:self];
    }
}

- (void)af_suspend {
    NSAssert([self respondsToSelector:@selector(state)], @"Does not respond to state");
    NSURLSessionTaskState state = [self state];
    [self af_suspend];
    
    if (state != NSURLSessionTaskStateSuspended) {
        [[NSNotificationCenter defaultCenter] postNotificationName:AFNSURLSessionTaskDidSuspendNotification object:self];
    }
}

@end


#pragma mark -
@interface AFURLSessionManagerTaskDelegate: NSObject<NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
- (instancetype)initWithTask:(NSURLSessionTask *)task;
@property (nonatomic, weak) AFURLSessionManager *manager;
@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, strong) NSProgress *uploadProgress;
@property (nonatomic, strong) NSProgress *downloadProgress;
@property (nonatomic, copy) NSURL *downloadFileURL;

@property (nonatomic, copy) AFURLSessionDownloadTaskDidFinishDownloadingBlock downloadTaskDidFinishDownloading;
@property (nonatomic, copy) AFURLSessionTaskProgressBlock uploadProgressBlock;
@property (nonatomic, copy) AFURLSessionTaskProgressBlock downloadProgressBlock;
@property (nonatomic, copy) AFURLSessionTaskCompletionHandler completionHandler;
@end

@implementation AFURLSessionManagerTaskDelegate
- (instancetype)initWithTask:(NSURLSessionTask *)task {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _mutableData = [NSMutableData data];
    _uploadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    _downloadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    
    __weak __typeof__(task) weakTask = task;
    for (NSProgress *progress in @[_uploadProgress, _downloadProgress]) {
        progress.totalUnitCount = NSURLSessionTransferSizeUnknown;
        progress.cancellable = YES;
        progress.cancellationHandler = ^{
            [weakTask cancel];
        };
        progress.pausable = YES;
        progress.pausingHandler = ^{
            [weakTask suspend];
        };
        if (@available(macOS 10.11, *)) {
            progress.resumingHandler = ^{
                [weakTask resume];
            };
        }
        [progress addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                      options:NSKeyValueObservingOptionNew
                      context:NULL];
        
        
    }
    
    return self;
}


- (void)dealloc
{
    [self.downloadProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
    [self.uploadProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
}

#pragma mark - NSProgress Tracking
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([object isEqual:self.downloadProgress]) {
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock(object);
        }
    } else if ([object isEqual:self.uploadProgress]) {
        if (self.uploadProgressBlock) {
            self.uploadProgressBlock(object);
        }
    }
}

static const void * const AuthenticationChallengeErrorKey = &AuthenticationChallengeErrorKey;

#pragma mark - NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session 
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    error = objc_getAssociatedObject(task, AuthenticationChallengeErrorKey) ?: error;
    __strong AFURLSessionManager *manager = self.manager;
    
    __block id responseObject = nil;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
//    userInfo[AFNetworkingTaskDidCompleteResponseSerializerKey] = manager.responseSerializer;
    
    NSData *data = nil;
    if (self.mutableData) {
        data = [self.mutableData copy];
        self.mutableData = nil;
    }
    
    if (self.downloadFileURL) {
        userInfo[AFNetworkingTaskDidCompleteAssetPathKey] = self.downloadFileURL;
    } else if (data) {
        userInfo[AFNetworkingTaskDidCompleteResponseDataKey] = data;
    }
    
    if (error) {
        userInfo[AFNetworkingTaskDidCompleteErrorKey] = error;
        
        dispatch_group_async(url_session_manager_completion_group(), dispatch_get_main_queue(), ^{
            if (self.completionHandler) {
                self.completionHandler(task.response, responseObject, error);
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidCompleteNotification object:task userInfo:userInfo];
            });
        });
    } else {
        
        dispatch_async(url_session_manager_processing_queue(), ^{
            NSError *serializationError = nil;
            //TODO: 任务完成
            
            if (self.downloadFileURL) {
                responseObject = self.downloadFileURL;
            }
            
            if (responseObject) {
                userInfo[AFNetworkingTaskDidCompleteSerializedResponseKey] = responseObject;
            }
            
            if (serializationError) {
                userInfo[AFNetworkingTaskDidCompleteErrorKey] = serializationError;
            }
            
            dispatch_group_async(url_session_manager_completion_group(), dispatch_get_main_queue(), ^{
                if (self.completionHandler) {
                    self.completionHandler(task.response, responseObject, serializationError);
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidCompleteNotification object:task userInfo:userInfo];
                });
            });
        });
    }
}


#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session 
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    self.downloadProgress.totalUnitCount = dataTask.countOfBytesExpectedToReceive;
    self.downloadProgress.completedUnitCount = dataTask.countOfBytesReceived;
    
    [self.mutableData appendData:data];
}


- (void)URLSession:(NSURLSession *)session 
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    self.uploadProgress.totalUnitCount = task.countOfBytesExpectedToSend;
    self.uploadProgress.completedUnitCount = task.countOfBytesSent;
}

#pragma mark - NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session 
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    self.downloadProgress.totalUnitCount = totalBytesExpectedToWrite;
    self.downloadProgress.completedUnitCount = totalBytesWritten;
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes
{
    self.downloadProgress.totalUnitCount = expectedTotalBytes;
    self.downloadProgress.completedUnitCount = fileOffset;
}


- (void)URLSession:(NSURLSession *)session 
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    self.downloadFileURL = nil;
    
    if (self.downloadTaskDidFinishDownloading) {
        self.downloadFileURL = self.downloadTaskDidFinishDownloading(session, downloadTask, location);
        if (self.downloadFileURL) {
            NSError *fileManagerError = nil;
            
            if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:self.downloadFileURL error:&fileManagerError]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:AFURLSessionDownloadTaskDidFailToMoveFileNotification object:downloadTask userInfo:fileManagerError.userInfo];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:AFURLSessionDownloadTaskDidMoveFileSuccessfullyNotification object:downloadTask userInfo:nil];
            }
        }
    }
}

@end


@interface AFURLSessionManager()
@property (readwrite, nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (readwrite, nonatomic, strong) NSLock *lock;

@property (readwrite, nonatomic, strong) NSURLSession *session;
@property (readwrite, nonatomic, strong) NSOperationQueue *operationQueue;
@property (readonly, nonatomic, copy) NSString *taskDescriptionForSessionTasks;
@property (readwrite, nonatomic, strong) NSMutableDictionary *mutableTaskDelegatesKeyedByTaskIdentifier; // key:NSURLSessionTask.taskIdentifier value: datadelegate
@property (readwrite, nonatomic, copy) AFURLSessionDidReceiveAuthenticationChallengeBlock sessionDidReceiveAuthenticationChallenge;
@property (readwrite, nonatomic, copy) AFURLSessionTaskDidCompleteBlock taskDidComplete;


@end


@implementation AFURLSessionManager

- (instancetype)init {
    return [self initWithSessionConfiguration:nil];
}


- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    if (!configuration) {
        configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    /// 初始化操作队列，并设置串行队列，设置最大并发数为1
    self.sessionConfiguration = configuration;
    /// ⚠️⚠️⚠️
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = 1;
    
    /// 2. 初始化字典可变字典 task的id作为key， 代理对象作为value
    self.mutableTaskDelegatesKeyedByTaskIdentifier = [[NSMutableDictionary alloc] init];
    self.lock = [[NSLock alloc] init];
    self.lock.name = AFURLSessionManagerLockName;
    
    /// 3. 获取所有的task，设置一遍delegate用来异步的获取当前的session的所有未完成的任务
    /// getTasksWithCompletionHandler : 异步的返回这个session的所有内容
    [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
        for (NSURLSessionDataTask *task in dataTasks) {
            [self addDelegateForDataTask:task uploadProgress:nil downloadProgress:nil completionHandler:nil];
        }
        
        for (NSURLSessionUploadTask *uploadTask in uploadTasks) {
            [self addDelegateForUploadTask:uploadTask progress:nil completionHandler:nil];
        }
        
        for (NSURLSessionDownloadTask *downloadTask in downloadTasks) {
            [self addDelegateForDownloadTask:downloadTask progress:nil destination:nil completionHandler:nil];
        }
    }];
    
    
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
#pragma mark -
-(NSURLSession *)session
{
    @synchronized (self) {
        if (!_session) {
            _session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:self.operationQueue];
        }
        return _session;
    }
}

- (NSString *)taskDescriptionForSessionTasks {
    return [NSString stringWithFormat:@"%p", self];
}


- (void)setSessionDidReceiveAuthenticationChallengeBlock:(NSURLSessionAuthChallengeDisposition (^)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential))block {
    self.sessionDidReceiveAuthenticationChallenge = block;
}

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(URLSession:didReceiveChallenge:completionHandler:)) {
        return self.sessionDidReceiveAuthenticationChallenge != nil;
    }
    
    return [[self class] instancesRespondToSelector:selector];
}

#pragma mark - NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    NSAssert(self.sessionDidReceiveAuthenticationChallenge != nil, @"`respondsToSelector:` implementation forces `URLSession:didReceiveChallenge:completionHandler:` to be called only if `self.sessionDidReceiveAuthenticationChallenge` is not nil");

    NSURLCredential *credential = nil;
    NSURLSessionAuthChallengeDisposition disposition = self.sessionDidReceiveAuthenticationChallenge(session, challenge, &credential);

    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}



- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    AFURLSessionManagerTaskDelegate *delegate = [self delegateForTask:task];

    // delegate may be nil when completing a task in the background
    if (delegate) {
        [delegate URLSession:session task:task didCompleteWithError:error];

        [self removeDelegateForTask:task];
    }

    if (self.taskDidComplete) {
        self.taskDidComplete(session, task, error);
    }
}

- (void)taskDidResume:(NSNotification *)notification
{
    NSURLSessionTask *task = notification.object;
    if ([task respondsToSelector:@selector(taskDescription)]) {
        if ([task.taskDescription isEqualToString:self.taskDescriptionForSessionTasks]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidResumeNotification object:task];
            });
        }
    }
}

- (void)taskDidSuspend:(NSNotification *)notification
{
    NSURLSessionTask *task = notification.object;
    if ([task respondsToSelector:@selector(taskDescription)]) {
        if ([task.taskDescription isEqualToString:self.taskDescriptionForSessionTasks]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidSuspendNotification object:task];
            });
        }
    }
}

#pragma mark -
- (void)addNotificationObserverForTask:(NSURLSessionTask *)task {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidResume:) name:AFNSURLSessionTaskDidResumeNotification object:task];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidSuspend:) name:AFNSURLSessionTaskDidSuspendNotification object:task];
}

- (void)removeNotificationObserverForTask:(NSURLSessionTask *)task {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNSURLSessionTaskDidSuspendNotification object:task];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNSURLSessionTaskDidResumeNotification object:task];
}

#pragma mark -
- (AFURLSessionManagerTaskDelegate *)delegateForTask:(NSURLSessionTask *)task {
    NSParameterAssert(task);

    AFURLSessionManagerTaskDelegate *delegate = nil;
    [self.lock lock];
    delegate = self.mutableTaskDelegatesKeyedByTaskIdentifier[@(task.taskIdentifier)];
    [self.lock unlock];

    return delegate;
}

-(void)setDelegate:(AFURLSessionManagerTaskDelegate *)delegate
           forTask:(NSURLSessionTask *)task
{
    NSParameterAssert(task);
    NSParameterAssert(delegate);
    
    [self.lock lock];
    self.mutableTaskDelegatesKeyedByTaskIdentifier[@(task.taskIdentifier)] = delegate;
    [self addNotificationObserverForTask:task];
    [self.lock unlock];
}

- (void)removeDelegateForTask:(NSURLSessionTask *)task {
    NSParameterAssert(task);

    [self.lock lock];
    [self removeNotificationObserverForTask:task];
    [self.mutableTaskDelegatesKeyedByTaskIdentifier removeObjectForKey:@(task.taskIdentifier)];
    [self.lock unlock];
}

#pragma mark -
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request 
                               uploadProgress:(void (^)(NSProgress * _Nonnull))uploadProgressBlock
                             downloadProgress:(void (^)(NSProgress * _Nonnull))downloadProgressBlock
                            completionHandler:(void (^)(NSURLResponse * _Nonnull, id _Nullable, NSError * _Nullable))completionHandler
{
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request];
    
    [self addDelegateForDataTask:dataTask uploadProgress:uploadProgressBlock downloadProgress:downloadProgressBlock completionHandler:completionHandler];
    return dataTask;
}


#pragma mark -
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request 
                                         fromFile:(NSURL *)fileURL
                                         progress:(void (^)(NSProgress * _Nonnull))uploadProgressBlock
                                completionHandler:(void (^)(NSURLResponse * _Nonnull, id _Nonnull responseObject, NSError * _Nullable))completionHandler
{
    NSURLSessionUploadTask *uploadTask = [self.session uploadTaskWithRequest:request fromFile:fileURL];
    
    if (uploadTask) {
        [self addDelegateForUploadTask:uploadTask progress:uploadProgressBlock completionHandler:completionHandler];
    }
    
    return uploadTask;
}


- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request 
                                         fromData:(NSData *)bodyData
                                         progress:(void (^)(NSProgress * _Nonnull))uploadProgressBlock
                                completionHandler:(void (^)(NSURLResponse * _Nonnull, id _Nullable, NSError * _Nullable))completionHandler
{
    NSURLSessionUploadTask *uploadTask = [self.session uploadTaskWithRequest:request fromData:bodyData];
    
    [self addDelegateForUploadTask:uploadTask progress:uploadProgressBlock completionHandler:completionHandler];
    
    return uploadTask;
}

- (NSURLSessionUploadTask *)uploadTaskWithStreamRequest:(NSURLRequest *)request 
                                               progress:(void (^)(NSProgress * _Nonnull))uploadProgressBlock
                                      completionHandler:(void (^)(NSURLResponse * _Nonnull, id _Nullable, NSError * _Nullable))completionHandler
{
    NSURLSessionUploadTask *uploadTask = [self.session uploadTaskWithStreamedRequest:request];
    
    [self addDelegateForUploadTask:uploadTask progress:uploadProgressBlock completionHandler:completionHandler];
    
    return uploadTask;
}


#pragma mark -

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request 
                                             progress:(void (^)(NSProgress * _Nonnull))downloadProgressBlock
                                          destination:(NSURL * _Nonnull (^)(NSURL * _Nonnull, NSURLResponse * _Nonnull))destination
                                    completionHandler:(void (^)(NSURLResponse * _Nonnull, NSURL * _Nullable, NSError * _Nullable))completionHandler
{
    NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithRequest:request];
    
    [self addDelegateForDownloadTask:downloadTask progress:downloadProgressBlock destination:destination completionHandler:completionHandler];
    
    return downloadTask;
}


- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData 
                                                progress:(void (^)(NSProgress * _Nonnull))downloadProgressBlock
                                             destination:(NSURL * _Nonnull (^)(NSURL * _Nonnull, NSURLResponse * _Nonnull))destination
                                       completionHandler:(void (^)(NSURLResponse * _Nonnull, NSURL * _Nullable, NSError * _Nullable))completionHandler
{
    NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithResumeData:resumeData];
    
    [self addDelegateForDownloadTask:downloadTask progress:downloadProgressBlock destination:destination completionHandler:completionHandler];
    
    return downloadTask;
}

- (void)addDelegateForDataTask:(NSURLSessionDataTask *)dataTask
                uploadProgress:(nullable void(^)(NSProgress *uploadProgress)) uploadProgressBlock
              downloadProgress:(nullable void(^)(NSProgress *downloadProgress)) downloadProgressBlock
             completionHandler:(void(^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    AFURLSessionManagerTaskDelegate *delegate = [[AFURLSessionManagerTaskDelegate alloc] initWithTask:dataTask];
    delegate.manager = self;
    delegate.completionHandler = completionHandler;
    
    dataTask.taskDescription = self.taskDescriptionForSessionTasks;
    [self setDelegate:delegate forTask:dataTask];
    
    delegate.uploadProgressBlock = uploadProgressBlock;
    delegate.downloadProgressBlock = downloadProgressBlock;
}

- (void)addDelegateForUploadTask:(NSURLSessionUploadTask *)uploadTask
                        progress:(void (^)(NSProgress *uploadProgress)) uploadProgressBlock
               completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    AFURLSessionManagerTaskDelegate *delegate = [[AFURLSessionManagerTaskDelegate alloc] initWithTask:uploadTask];
    delegate.manager = self;
    delegate.completionHandler = completionHandler;
    
    uploadTask.taskDescription = self.taskDescriptionForSessionTasks;
    
    [self setDelegate:delegate forTask:uploadTask];
    
    delegate.uploadProgressBlock = uploadProgressBlock;
}


- (void)addDelegateForDownloadTask:(NSURLSessionDownloadTask *)downloadTask
              progress:(nullable void(^)(NSProgress *downloadProgress)) downloadProgressBlock
                       destination:(NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination
             completionHandler:(void(^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    AFURLSessionManagerTaskDelegate *delegate = [[AFURLSessionManagerTaskDelegate alloc] initWithTask:downloadTask];
    delegate.manager = self;
    delegate.completionHandler = completionHandler;
    if (destination) {
        delegate.downloadTaskDidFinishDownloading = ^NSURL *(NSURLSession *session, NSURLSessionDownloadTask *task, NSURL *location) {
            return destination(location, task.response);
        };
    }
    
    downloadTask.taskDescription = self.taskDescriptionForSessionTasks;
    
    [self setDelegate:delegate forTask:downloadTask];
    
    delegate.downloadProgressBlock = downloadProgressBlock;
}



#pragma mark - NSCopying
-(instancetype)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithSessionConfiguration:self.session.configuration];
}


@end
