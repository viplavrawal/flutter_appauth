#import "AppAuthIOSAuthorization.h"

@implementation AppAuthIOSAuthorization

- (id<OIDExternalUserAgentSession>) performAuthorization:(OIDServiceConfiguration *)serviceConfiguration clientId:(NSString*)clientId clientSecret:(NSString*)clientSecret scopes:(NSArray *)scopes redirectUrl:(NSString*)redirectUrl additionalParameters:(NSDictionary *)additionalParameters preferEphemeralSession:(BOOL)preferEphemeralSession result:(FlutterResult)result exchangeCode:(BOOL)exchangeCode nonce:(NSString*)nonce setGlobal:(void(*)(NSObject<OIDExternalUserAgent>* agent, FlutterResult result))setGlobal{
  NSString *codeVerifier = [OIDAuthorizationRequest generateCodeVerifier];
  NSString *codeChallenge = [OIDAuthorizationRequest codeChallengeS256ForVerifier:codeVerifier];

  OIDAuthorizationRequest *request =
  [[OIDAuthorizationRequest alloc] initWithConfiguration:serviceConfiguration
                                                clientId:clientId
                                            clientSecret:clientSecret
                                                   scope:[OIDScopeUtilities scopesWithArray:scopes]
                                             redirectURL:[NSURL URLWithString:redirectUrl]
                                            responseType:OIDResponseTypeCode
                                                   state:[OIDAuthorizationRequest generateState]
                                                   nonce: nonce != nil ? nonce : [OIDAuthorizationRequest generateState]
                                            codeVerifier:codeVerifier
                                           codeChallenge:codeChallenge
                                     codeChallengeMethod:OIDOAuthorizationRequestCodeChallengeMethodS256
                                    additionalParameters:additionalParameters];
  UIViewController *rootViewController =
  [UIApplication sharedApplication].delegate.window.rootViewController;
  if(exchangeCode) {
      id<OIDExternalUserAgent> externalUserAgent = [self userAgentWithViewController:rootViewController useEphemeralSession:preferEphemeralSession];
      setGlobal(externalUserAgent, result);
      return [OIDAuthState authStateByPresentingAuthorizationRequest:request externalUserAgent:externalUserAgent callback:^(OIDAuthState *_Nullable authState,
                                                                                                                                                  NSError *_Nullable error) {
          if(authState) {
              setGlobal(NULL, NULL);
              result([FlutterAppAuth processResponses:authState.lastTokenResponse authResponse:authState.lastAuthorizationResponse]);
              
          } else {
              setGlobal(NULL, NULL);
              [FlutterAppAuth finishWithError:AUTHORIZE_AND_EXCHANGE_CODE_ERROR_CODE message:[FlutterAppAuth formatMessageWithError:AUTHORIZE_ERROR_MESSAGE_FORMAT error:error] result:result];
          }
      }];
  } else {
      id<OIDExternalUserAgent> externalUserAgent = [self userAgentWithViewController:rootViewController useEphemeralSession:preferEphemeralSession];
      setGlobal(externalUserAgent, result);
      return [OIDAuthorizationService presentAuthorizationRequest:request externalUserAgent:externalUserAgent callback:^(OIDAuthorizationResponse *_Nullable authorizationResponse, NSError *_Nullable error) {
          if(authorizationResponse) {
              NSMutableDictionary *processedResponse = [[NSMutableDictionary alloc] init];
              [processedResponse setObject:authorizationResponse.additionalParameters forKey:@"authorizationAdditionalParameters"];
              [processedResponse setObject:authorizationResponse.authorizationCode forKey:@"authorizationCode"];
              [processedResponse setObject:authorizationResponse.request.codeVerifier forKey:@"codeVerifier"];
              [processedResponse setObject:authorizationResponse.request.nonce forKey:@"nonce"];
              setGlobal(NULL, NULL);
              result(processedResponse);
          } else {
              setGlobal(NULL, NULL);
              [FlutterAppAuth finishWithError:AUTHORIZE_ERROR_CODE message:[FlutterAppAuth formatMessageWithError:AUTHORIZE_ERROR_MESSAGE_FORMAT error:error] result:result];
          }
      }];
  }
}

- (id<OIDExternalUserAgentSession>)performEndSessionRequest:(OIDServiceConfiguration *)serviceConfiguration requestParameters:(EndSessionRequestParameters *)requestParameters result:(FlutterResult)result {
  NSURL *postLogoutRedirectURL = requestParameters.postLogoutRedirectUrl ? [NSURL URLWithString:requestParameters.postLogoutRedirectUrl] : nil;
  
  OIDEndSessionRequest *endSessionRequest = requestParameters.state ? [[OIDEndSessionRequest alloc] initWithConfiguration:serviceConfiguration idTokenHint:requestParameters.idTokenHint postLogoutRedirectURL:postLogoutRedirectURL
                                                                                                                    state:requestParameters.state additionalParameters:requestParameters.additionalParameters] :[[OIDEndSessionRequest alloc] initWithConfiguration:serviceConfiguration idTokenHint:requestParameters.idTokenHint postLogoutRedirectURL:postLogoutRedirectURL
                                                                                                                                                                                                                                               additionalParameters:requestParameters.additionalParameters];

  UIViewController *rootViewController =
  [UIApplication sharedApplication].delegate.window.rootViewController;
  id<OIDExternalUserAgent> externalUserAgent = [self userAgentWithViewController:rootViewController useEphemeralSession:requestParameters.preferEphemeralSession];

  
  return [OIDAuthorizationService presentEndSessionRequest:endSessionRequest externalUserAgent:externalUserAgent callback:^(OIDEndSessionResponse * _Nullable endSessionResponse, NSError * _Nullable error) {
      if(!endSessionResponse) {
          NSString *message = [NSString stringWithFormat:END_SESSION_ERROR_MESSAGE_FORMAT, [error localizedDescription]];
          [FlutterAppAuth finishWithError:END_SESSION_ERROR_CODE message:message result:result];
          return;
      }
      NSMutableDictionary *processedResponse = [[NSMutableDictionary alloc] init];
      [processedResponse setObject:endSessionResponse.state forKey:@"state"];
      result(processedResponse);
  }];
}

- (id<OIDExternalUserAgent>)userAgentWithViewController:(UIViewController *)rootViewController useEphemeralSession:(BOOL)useEphemeralSession {
    if (useEphemeralSession) {
        return [[OIDExternalUserAgentIOSNoSSO alloc]
                initWithPresentingViewController:rootViewController];
    }
    return [[OIDExternalUserAgentIOS alloc]
            initWithPresentingViewController:rootViewController];
}

@end
