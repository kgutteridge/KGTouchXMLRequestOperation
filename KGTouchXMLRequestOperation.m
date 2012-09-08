//
//  KGTouchXMLRequestOperation.m
//
//  Created by Kieran Gutteridge on 01/03/2012.
//  Copyright (c) 2012 Intohand Ltd. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "KGTouchXMLRequestOperation.h"

static dispatch_queue_t kg_xml_request_operation_processing_queue;
static dispatch_queue_t xml_request_operation_processing_queue() {
    if (kg_xml_request_operation_processing_queue == NULL) {
        kg_xml_request_operation_processing_queue = dispatch_queue_create("uk.co.kgutteridge.networking.xml-request.processing", 0);
    }
    
    return kg_xml_request_operation_processing_queue;
}

@interface KGTouchXMLRequestOperation ()
@property (readwrite, nonatomic, retain) CXMLDocument* responseXML;
@property (readwrite, nonatomic, retain) NSError *XMLError;

+ (NSSet *)defaultAcceptableContentTypes;
+ (NSSet *)defaultAcceptablePathExtensions;
@end

@implementation KGTouchXMLRequestOperation
@synthesize responseXML = _responseXML;
@synthesize XMLError = _XMLError;

+ (KGTouchXMLRequestOperation *)XMLRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                                    success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, CXMLDocument* XML))success 
                                                    failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, CXMLDocument* XML))failure
{
    KGTouchXMLRequestOperation *requestOperation = [[[self alloc] initWithRequest:urlRequest] autorelease];
    [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success(operation.request, operation.response, responseObject);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(operation.request, operation.response, error, [(KGTouchXMLRequestOperation *)operation responseXML]);
        }
    }];
    
    return requestOperation;
}

+ (NSSet *)defaultAcceptableContentTypes {
     return [NSSet setWithObjects:@"application/xml", @"text/xml",@"application/xhtml+xml", @"text/html", nil];
}

+ (NSSet *)defaultAcceptablePathExtensions {
    return [NSSet setWithObjects:@"xml", nil];
}

+ (BOOL)canProcessRequest:(NSURLRequest *)request {
    return [[self defaultAcceptableContentTypes] containsObject:[request valueForHTTPHeaderField:@"Accept"]] || [[self defaultAcceptablePathExtensions] containsObject:[[request URL] pathExtension]];
}

- (id)initWithRequest:(NSURLRequest *)urlRequest 
{
    self = [super initWithRequest:urlRequest];
    if (!self) 
    {
        return nil;
    }    
    [[self class] addAcceptableContentTypes:[[self class] defaultAcceptableContentTypes]];
    
    return self;
}

- (void)dealloc {
    [_responseXML release];
    [_XMLError release];
    [super dealloc];
}

- (id)responseXML {
    if (!_responseXML && [self.responseData length] > 0 && [self isFinished]) 
    {
        NSError *error = nil;
        if ([self.responseData length] == 0) 
        {
            self.responseXML = nil;
        } 
        else 
        {
            self.responseXML = [[[CXMLDocument alloc] initWithData:self.responseData options:0 error:&error] autorelease];
        }
        self.XMLError = error;
    }
    return _responseXML;
}

- (NSError *)error 
{
    if (_XMLError) 
    {
        return _XMLError;
    } 
    else 
    {
        return [super error];
    }
}

- (void)setCompletionBlockWithSuccess:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                              failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    self.completionBlock = ^ {
        if ([self isCancelled]) {
            return;
        }
        
        if (self.error) 
        {
            
            if (failure) 
            {
                dispatch_async(dispatch_get_main_queue(), ^(void) 
                {
                    failure(self, self.error);
                });
            }
        } 
        else 
        {
            dispatch_async(xml_request_operation_processing_queue(), ^(void) {
                id XML = self.responseXML;
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    if (self.XMLError) {
                        if (failure) {
                            failure(self, self.XMLError);
                        }
                    } else {
                        if (success) {
                            success(self, XML);
                        }
                    }
                }); 
            });
        }
    };    
}

@end
