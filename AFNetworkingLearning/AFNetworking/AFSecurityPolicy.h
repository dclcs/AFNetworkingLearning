//
//  AFSecurityPolicy.h
//  AFNetworkingLearning
//
//  Created by cl d on 2023/12/31.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AFSSLPinningMode) {
    AFSSLPinningModeNone,
    AFSSLPinningModePublicKey,
    AFSSLPinningModeCertificate,
};


NS_ASSUME_NONNULL_BEGIN

@interface AFSecurityPolicy : NSObject <NSSecureCoding, NSCopying>

@end

NS_ASSUME_NONNULL_END
