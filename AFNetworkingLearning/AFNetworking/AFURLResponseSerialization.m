//
//  AFURLResponseSerialization.m
//  AFNetworkingLearning
//
//  Created by cl d on 2023/12/10.
//

#import "AFURLResponseSerialization.h"

NSString * const AFURLResponseSerializationErrorDomain = @"com.alamofire.error.serialization.response";
NSString * const AFNetworkingOperationFailingURLResponseErrorKey = @"com.alamofire.serialization.response.error.response";


static NSError * AFErrorWithUnderlyingError(NSError *error, NSError *underlyingError)
{
    if (!error) {
        return underlyingError;
    }
    
    if (!underlyingError || error.userInfo[NSUnderlyingErrorKey]) {
        return error;
    }
    
    NSMutableDictionary *mutableUserInfo = [error.userInfo mutableCopy];
    mutableUserInfo[NSUnderlyingErrorKey] = underlyingError;
    
    return [[NSError alloc] initWithDomain:error.domain code:error.code userInfo:mutableUserInfo];
}


static BOOL AFErrorOrUnderlyingErrorHasCodeInDomain(NSError *error, NSInteger code, NSString *domain) {
    if ([error.domain isEqualToString:domain] && error.code == code) {
        return YES;
    } else if (error.userInfo[NSUnderlyingErrorKey]) {
        return AFErrorOrUnderlyingErrorHasCodeInDomain(error.userInfo[NSUnderlyingErrorKey], code, domain);
    }

    return NO;
}


id AFJSONObjectByRemovingKeysWithNullValues(id JSONObject, NSJSONReadingOptions readingOptions) {
    if ([JSONObject isKindOfClass:[NSArray class]]) {
        NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:[(NSArray *)JSONObject count]];
        for (id value in (NSArray *)JSONObject) {
            if (![value isEqual:[NSNull null]]) {
                [mutableArray addObject:AFJSONObjectByRemovingKeysWithNullValues(value, readingOptions)];
            }
        }

        return (readingOptions & NSJSONReadingMutableContainers) ? mutableArray : [NSArray arrayWithArray:mutableArray];
    } else if ([JSONObject isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionaryWithDictionary:JSONObject];
        for (id <NSCopying> key in [(NSDictionary *)JSONObject allKeys]) {
            id value = (NSDictionary *)JSONObject[key];
            if (!value || [value isEqual:[NSNull null]]) {
                [mutableDictionary removeObjectForKey:key];
            } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                mutableDictionary[key] = AFJSONObjectByRemovingKeysWithNullValues(value, readingOptions);
            }
        }

        return (readingOptions & NSJSONReadingMutableContainers) ? mutableDictionary : [NSDictionary dictionaryWithDictionary:mutableDictionary];
    }

    return JSONObject;
}

@implementation AFHTTPResponseSerializer

+ (instancetype)serializer
{
    return [[self alloc] init];
}


- (instancetype)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    self.acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    return self;
}


#pragma mark -
- (BOOL)validateResponse:(NSHTTPURLResponse *)response 
                    data:(NSData *)data
                   error:(NSError * _Nullable __autoreleasing *)error
{
    BOOL responseIsValid = YES;
    NSError *validationError = nil;
    
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        if (self.acceptableContentTypes && 
            ![self.acceptableContentTypes containsObject: [response MIMEType]] &&
            !([response MIMEType] == nil && [data length] == 0)) {
            
            if ([data length] > 0 && [response URL]) {
                NSMutableDictionary *mutableUserInfo = [@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"Request faild unacceptable content-type : %@", @"AFNetworking", nil), [response MIMEType]],
                    NSURLErrorFailingURLErrorKey:[response URL],
                    AFNetworkingOperationFailingURLResponseErrorKey: response,
                } mutableCopy];
                if (data) {
                    mutableUserInfo[AFNetworkingOperationFailingURLResponseErrorKey]  = data;
                }
                
                validationError = AFErrorWithUnderlyingError([NSError errorWithDomain:AFURLResponseSerializationErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:mutableUserInfo], validationError);
                
            }
            responseIsValid = NO;
        }
        
        if (self.acceptableStatusCodes && ![self.acceptableStatusCodes containsIndex:(NSUInteger)response.statusCode] && [response URL]) {
            NSMutableDictionary *mutableUserInfo = [@{
                                               NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"Request failed: %@ (%ld)", @"AFNetworking", nil), [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], (long)response.statusCode],
                                               NSURLErrorFailingURLErrorKey:[response URL],
                                               AFNetworkingOperationFailingURLResponseErrorKey: response,
                                       } mutableCopy];
            if (data) {
                mutableUserInfo[AFNetworkingOperationFailingURLResponseErrorKey] = data;
            }
            
            validationError = AFErrorWithUnderlyingError([NSError errorWithDomain:AFURLResponseSerializationErrorDomain code:NSURLErrorBadServerResponse userInfo:mutableUserInfo], validationError);
            responseIsValid = NO;
        }
    }
    
    if (error && !responseIsValid) {
        *error = validationError;
    }
    
    return responseIsValid;
}


#pragma mark - AFURLResponseSerialization

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError * _Nullable __autoreleasing *)error
{
    [self validateResponse:(NSHTTPURLResponse *)response data:data error:error];
    return data;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    self = [self init];
    if (!self) {
        return nil;
    }
    
    self.acceptableStatusCodes = [decoder decodeObjectOfClass:[NSIndexSet class] forKey:NSStringFromSelector(@selector(acceptableStatusCodes))];
    self.acceptableContentTypes = [decoder decodeObjectOfClass:[NSSet class] forKey:NSStringFromSelector(@selector(acceptableContentTypes))];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.acceptableStatusCodes forKey:NSStringFromSelector(@selector(acceptableStatusCodes))];
    [coder encodeObject:self.acceptableContentTypes forKey:NSStringFromSelector(@selector(acceptableContentTypes))];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    AFHTTPResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.acceptableStatusCodes = [self.acceptableStatusCodes copyWithZone:zone];
    serializer.acceptableContentTypes = [self.acceptableContentTypes copyWithZone:zone];

    return serializer;
}

@end


@implementation AFJSONResponseSerializer

+ (instancetype)serializer
{
    return [self serializerWithReadingOptions:(NSJSONReadingOptions)0];
}

+ (instancetype)serializerWithReadingOptions:(NSJSONReadingOptions)readingOptions
{
    AFJSONResponseSerializer *serializer = [[self alloc] init];
    serializer.readingOptions = readingOptions;
    
    return serializer;
}

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    self.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", nil];
    return self;
}

#pragma mark - AFURLResponseSerialization

- (id)responseObjectForResponse:(NSURLResponse *)response 
                           data:(NSData *)data
                          error:(NSError * _Nullable __autoreleasing *)error
{
    if (![self validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        if (!error || AFErrorOrUnderlyingErrorHasCodeInDomain(*error, NSURLErrorCannotDecodeContentData, AFURLResponseSerializationErrorDomain)) {
            return nil;
        }
    }
    
    BOOL isSpace = [data isEqualToData:[NSData dataWithBytes:" " length:1]];
    if (data.length == 0 || isSpace) {
        return nil;
    }
    
    NSError *seriablizationError = nil;
    id responseObject = [NSJSONSerialization JSONObjectWithData:data options:self.readingOptions error:&seriablizationError];
    
    if (!responseObject) {
        if (error) {
            *error = AFErrorWithUnderlyingError(seriablizationError, *error);
        }
        return nil;
    }
    
    if (self.removesKeysWithNullValues) {
        return AFJSONObjectByRemovingKeysWithNullValues(responseObject, self.readingOptions);
    }
    
    return responseObject;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }

    self.readingOptions = [[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(readingOptions))] unsignedIntegerValue];
    self.removesKeysWithNullValues = [[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(removesKeysWithNullValues))] boolValue];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeObject:@(self.readingOptions) forKey:NSStringFromSelector(@selector(readingOptions))];
    [coder encodeObject:@(self.removesKeysWithNullValues) forKey:NSStringFromSelector(@selector(removesKeysWithNullValues))];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    AFJSONResponseSerializer *serializer = [super copyWithZone:zone];
    serializer.readingOptions = self.readingOptions;
    serializer.removesKeysWithNullValues = self.removesKeysWithNullValues;

    return serializer;
}


@end
