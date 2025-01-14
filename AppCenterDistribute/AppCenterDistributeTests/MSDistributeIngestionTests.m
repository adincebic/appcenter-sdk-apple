// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSConstants+Internal.h"
#import "MSDistribute.h"
#import "MSDistributeIngestion.h"
#import "MSDistributePrivate.h"
#import "MSHttpClient.h"
#import "MSHttpIngestionPrivate.h"
#import "MSHttpTestUtil.h"
#import "MSLoggerInternal.h"
#import "MSMockLog.h"
#import "MSTestFrameworks.h"
#import "MSTestUtil.h"
#import "MSUtility+StringFormatting.h"

@interface MSDistributeIngestionTests : XCTestCase

@property id httpClientMock;
@property id httpClientClassMock;
@property NSString *baseUrl;
@property NSString *actualUrl;
@property NSString *updateToken;
@property NSString *distributionGroupId;
@property MSDistributeIngestion *sut;

@end

static NSString *const kMSTestAppSecret = @"TestAppSecret";

@implementation MSDistributeIngestionTests

- (void)setUp {
  self.baseUrl = @"https://contoso.com";
  self.updateToken = @"updateToken";
  self.distributionGroupId = @"groupId";
  self.actualUrl = [NSString stringWithFormat:@"%@/sdk/apps/%@/releases/latest", self.baseUrl, kMSTestAppSecret];
  self.httpClientMock = OCMPartialMock([MSHttpClient new]);
  self.httpClientClassMock = OCMClassMock([MSHttpClient class]);
  OCMStub([self.httpClientClassMock alloc]).andReturn(self.httpClientMock);
  self.sut = [[MSDistributeIngestion alloc] initWithHttpClient:self.httpClientMock
                                                       baseUrl:self.baseUrl
                                                     appSecret:kMSTestAppSecret
                                                   updateToken:self.updateToken
                                           distributionGroupId:self.distributionGroupId
                                                  queryStrings:@{}];
}

- (void)tearDown {
  [self.httpClientMock stopMocking];
  [self.httpClientClassMock stopMocking];
}
#pragma mark - Tests

- (void)testGetHeadersAndNilPayload {

  // When
  NSDictionary *headers = [self.sut getHeadersWithData:nil eTag:nil authToken:nil];
  NSData *payload = [self.sut getPayloadWithData:nil];
  [self.sut sendAsync:[NSData new]
      completionHandler:^(NSString *_Nonnull callId, NSHTTPURLResponse *_Nullable response __unused, NSData *_Nullable data __unused,
                          NSError *_Nullable error __unused) {
        (void)callId;
      }];

  // Then
  assertThat(headers, equalTo(@{kMSHeaderUpdateApiToken : self.updateToken}));
  OCMVerify([self.httpClientMock sendAsync:[NSURL URLWithString:self.actualUrl]
                                    method:@"GET"
                                   headers:OCMOCK_ANY
                                      data:OCMOCK_ANY
                            retryIntervals:OCMOCK_ANY
                        compressionEnabled:OCMOCK_ANY
                         completionHandler:OCMOCK_ANY]);
  XCTAssertNil(payload);
}

- (void)testGetHeadersWithUpdateTokenAndNilPayload {

  // If
  NSString *updateToken = @"updateToken";
  [MSLogger setCurrentLogLevel:MSLogLevelVerbose];
  id distributeMock = OCMPartialMock([MSDistribute sharedInstance]);
  OCMStub([distributeMock appSecret]).andReturn(@"secret");

  // When
  NSDictionary *headers = [self.sut getHeadersWithData:[NSData new] eTag:nil authToken:nil];
  NSData *payload = [self.sut getPayloadWithData:[NSData new]];
  [self.sut sendAsync:[NSData new]
      completionHandler:^(NSString *_Nonnull callId, NSHTTPURLResponse *_Nullable response __unused, NSData *_Nullable data __unused,
                          NSError *_Nullable error __unused) {
        (void)callId;
      }];

  // Then
  assertThat(headers, equalTo(@{kMSHeaderUpdateApiToken : updateToken}));
  OCMVerify([self.httpClientMock sendAsync:[NSURL URLWithString:self.actualUrl]
                                    method:@"GET"
                                   headers:OCMOCK_ANY
                                      data:OCMOCK_ANY
                            retryIntervals:OCMOCK_ANY
                        compressionEnabled:OCMOCK_ANY
                         completionHandler:OCMOCK_ANY]);
  XCTAssertNil(payload);

  // Cleanup
  [distributeMock stopMocking];
}

- (void)testHideTokenInResponse {

  // If
  id mockUtility = OCMClassMock([MSUtility class]);
  id mockLogger = OCMClassMock([MSLogger class]);
  id mockDevice = OCMPartialMock([MSDevice new]);
  OCMStub([mockDevice isValid]).andReturn(YES);
  OCMStub([mockLogger currentLogLevel]).andReturn(MSLogLevelVerbose);
  OCMStub(ClassMethod([mockUtility obfuscateString:OCMOCK_ANY
                               searchingForPattern:kMSRedirectUriPattern
                             toReplaceWithTemplate:kMSRedirectUriObfuscatedTemplate]));
  NSData *data = [@"{\"redirect_uri\":\"secrets\"}" dataUsingEncoding:NSUTF8StringEncoding];
  MSLogContainer *container = [MSTestUtil createLogContainerWithId:@"1" device:mockDevice];
  XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"Request completed."];

  // When
  [MSHttpTestUtil stubResponseWithData:data statusCode:MSHTTPCodesNo200OK headers:self.sut.httpHeaders name:NSStringFromSelector(_cmd)];
  [self.sut sendAsync:container
              authToken:nil
      completionHandler:^(__unused NSString *batchId, __unused NSHTTPURLResponse *response, __unused NSData *responseData,
                          __unused NSError *error) {
        [requestCompletedExpectation fulfill];
      }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *error) {
                                 OCMVerify(ClassMethod([mockUtility obfuscateString:OCMOCK_ANY
                                                                searchingForPattern:kMSRedirectUriPattern
                                                              toReplaceWithTemplate:kMSRedirectUriObfuscatedTemplate]));
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];

  // Clear
  [mockUtility stopMocking];
  [mockLogger stopMocking];
}

- (void)testHttpClientDelegateObfuscateHeaderValue {

  // If
  id mockLogger = OCMClassMock([MSLogger class]);
  id mockHttpUtil = OCMClassMock([MSHttpUtil class]);
  OCMStub([mockLogger currentLogLevel]).andReturn(MSLogLevelVerbose);
  OCMStub(ClassMethod([mockHttpUtil hideSecret:OCMOCK_ANY])).andDo(nil);
  NSString *appSecret = @"TestAppSecret";
  NSDictionary<NSString *, NSString *> *headers = @{kMSHeaderUpdateApiToken : appSecret};
  NSURL *url = [NSURL new];

  // When
  [self.sut willSendHTTPRequestToURL:url withHeaders:headers];

  // Then
  OCMVerify([mockHttpUtil hideSecret:appSecret]);
  [mockLogger stopMocking];
  [mockHttpUtil stopMocking];
}

- (void)testObfuscateResponsePayload {

  // If
  NSString *payload = @"{\"redirect_uri\" : \"some secrets here\"}";
  NSString *expectedPayload = [payload stringByReplacingOccurrencesOfString:@"some secrets here" withString:@"***"];

  // When
  NSString *actualPayload = [self.sut obfuscateResponsePayload:payload];

  // Then
  XCTAssertTrue([actualPayload isEqualToString:expectedPayload]);
}

@end
