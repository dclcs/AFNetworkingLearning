//
//  AFURLResponseSerialization.h
//  AFNetworkingLearning
//
//  Created by cl d on 2023/12/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol AFURLResponseSerialization <NSObject, NSSecureCoding, NSCopying>

/**
 reponse object decoded
 */
- (nullable id)responseObjectForResponse:(nullable NSURLResponse *)response
                                    data:(nullable NSData *)data
                                   error:(NSError * _Nullable __autoreleasing *)error;

@end



@interface AFHTTPResponseSerializer : NSObject <AFURLResponseSerialization>


- (instancetype)init;


+ (instancetype)serializer;

@property (nonatomic, copy, nullable) NSIndexSet *acceptableStatusCodes;

@property (nonatomic, copy, nullable) NSSet <NSString *> *acceptableContentTypes;


- (BOOL)validateResponse:(nullable NSHTTPURLResponse *)response
                    data:(nullable NSData *)data
                   error:(NSError * _Nullable __autoreleasing *)err;


@end



@interface AFJSONResponseSerializer : AFHTTPResponseSerializer

- (instancetype)init;

@property (nonatomic, assign) NSJSONReadingOptions readingOptions;

@property (nonatomic, assign) BOOL removesKeysWithNullValues;

+ (instancetype)serializerWithReadingOptions:(NSJSONReadingOptions)readingOptions;

@end


NS_ASSUME_NONNULL_END
