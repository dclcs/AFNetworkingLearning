//
//  AFURLRequestSerialization.h
//  AFNetworkingLearning
//
//  Created by cl d on 2023/12/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AFURLRequestSerialization <NSObject, NSSecureCoding, NSCopying>

- (nullable NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request
                                        withParameters:(nullable id)parameters
                                                 error:(NSError * _Nullable __autoreleasing *)error NS_SWIFT_NOTHROW;

@end



@interface AFHTTPRequestSerializer : NSObject <AFURLRequestSerialization>

@property (nonatomic, assign) NSStringEncoding stringEncoding;

@property (nonatomic, strong) NSSet <NSString *> *HTTPMethodsEncodingParametersInURI;

@property (readonly, nonatomic, strong) NSDictionary <NSString *, NSString *> *HTTPRequestHeaders;

+ (instancetype)serializer;


- (nullable NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                          URLString:(NSString *)URLString
                                         parameters:(nullable id)parameters
                                              error:(NSError * _Nullable __autoreleasing *)error;

@end


typedef NS_ENUM(NSUInteger, AFHTTPRequestQueryStringSerializationStyle) {
    AFHTTPRequestQueryStringDefaultStyle = 0,
};

NS_ASSUME_NONNULL_END
