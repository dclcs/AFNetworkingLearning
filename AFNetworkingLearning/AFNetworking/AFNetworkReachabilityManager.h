//
//  AFNetworkReachabilityManager.h
//  AFNetworkingLearning
//
//  Created by cl d on 2023/12/31.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>


typedef NS_ENUM(NSInteger, AFNetworkReachabilityStatus) {
    AFNetworkReachabilityStatusUnknown          = -1,
    AFNetworkReachabilityStatusNotReachable     = 0,
    AFNetworkReachabilityStatusReachableViaWWAN = 1,
    AFNetworkReachabilityStatusReachableViaWiFi = 2,
};

NS_ASSUME_NONNULL_BEGIN

@interface AFNetworkReachabilityManager : NSObject

+ (instancetype)sharedManager;

+ (instancetype)manager;

@property (readonly, nonatomic, assign) AFNetworkReachabilityStatus networkReachabilityStatus;


@property (readonly, nonatomic, assign, getter = isReachable) BOOL reachable;



@end

NS_ASSUME_NONNULL_END
