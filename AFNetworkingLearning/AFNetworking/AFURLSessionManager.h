//
//  AFURLSessionManager.h
//  AFNetworkingLearning
//
//  Created by cl d on 2023/11/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AFURLSessionManager : NSObject


@property (readonly, nonatomic, strong) NSURLSession *session;

@property (readonly, nonatomic, strong) NSOperationQueue *operationQueue;


@end

NS_ASSUME_NONNULL_END
