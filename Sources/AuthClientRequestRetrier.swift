import Foundation
import UIKit
import Alamofire
import HTTPStatusCodes

open class AuthClientRequestRetrier: RequestRetrier, @unchecked Sendable {
    fileprivate var maxRetryCount: UInt = 5
    fileprivate var retryWaitSeconds: Int = 1
    fileprivate var rateLimitWaitSeconds: Int = 60
    open var isReloadingCancelled = false
    open var shouldRetryRateLimit = false
    var shouldAlwaysShowLoginAgain = false
    
    public init() {
        
    }
    
    open func retry(_ request: Request, for _: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        if isReloadingCancelled {
            completion(.doNotRetry)
            return
        }
        
        if shouldRetryRequest(error, request: request) {
            if request.retryCount >= maxRetryCount {
                completion(.doNotRetry)
                return
            }
            
            completion(.retryWithDelay(1.0))
            return
        } else if shouldRetryRateLimitRequest(error, request: request) {
            var autoRetry = rateLimitWaitSeconds * (request.retryCount + 1)
            var autoRetryTimer: Timer?
            
            DispatchQueue.main.async { [weak self] in
                
                guard let self = self else {
                    return
                }
                
                let actionSheetController = UIAlertController(title: NSLocalizedString("Rate Limit Exceeded", comment: ""), message: String(format: "You have made too many requests. If you do nothing, the app will retry automatically in %d seconds.", autoRetry), preferredStyle: .alert)
                
                actionSheetController.addAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                    NotificationCenter.default.post(name: AuthClient.didRateLimitCancelled, object: nil, userInfo: nil)
                    
                    autoRetryTimer?.invalidate()
                    completion(.doNotRetry)
                    return
                }
                
                if request.retryCount >= 3 || self.shouldAlwaysShowLoginAgain {
                    actionSheetController.addAction(title: NSLocalizedString("Login Again", comment: ""), style: .default) { [weak self] _ in
                        guard let self = self, !self.isReloadingCancelled else {
                            return
                        }
                        
                        NotificationCenter.default.post(name: AuthClient.didRateLimitSessionExpired, object: nil, userInfo: nil)
                        
                        autoRetryTimer?.invalidate()
                        completion(.doNotRetryWithError(APWebAuthenticationError.canceled))
                        return
                    }
                }
                
                actionSheetController.addAction(title: NSLocalizedString("Retry Now", comment: ""), style: .default) { [weak self] _ in
                    guard let self = self, !self.isReloadingCancelled else {
                        return
                    }
                    
                    autoRetryTimer?.invalidate()
                    completion(.retry)
                    return
                }
                
                actionSheetController.preferredAction = actionSheetController.actions[actionSheetController.actions.count - 1]
                actionSheetController.show()
                
                autoRetryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                    
                    if autoRetry == 1 {
                        timer.invalidate()
                        actionSheetController.dismiss(animated: true)
                        
                        completion(.retryWithDelay(0.1))
                        return
                    }
                    
                    autoRetry = autoRetry - 1
                    DispatchQueue.main.async {
                        actionSheetController.message = String(format: "You have made too many requests. If you do nothing, the app will retry automatically in %d seconds.", autoRetry)
                    }
                }
            }
            
            return
        }
        
        completion(.doNotRetry)
    }
    
    open func shouldRetryRequest(_ error: Error?, request: Request?) -> Bool {
        if isReloadingCancelled {
            return false
        }
        
        if let currentError = error as? URLError {
            if currentError.code == URLError.timedOut ||
                currentError.code == URLError.dnsLookupFailed ||
                currentError.code == URLError.notConnectedToInternet ||
                currentError.code == URLError.cannotFindHost ||
                currentError.code == URLError.networkConnectionLost
            {
                return true
            }
        }
        
        if let afError = error as? AFError, let currentError = afError.underlyingError as? URLError {
            if currentError.code == URLError.timedOut ||
                currentError.code == URLError.dnsLookupFailed ||
                currentError.code == URLError.notConnectedToInternet ||
                currentError.code == URLError.cannotFindHost ||
                currentError.code == URLError.networkConnectionLost
            {
                return true
            }
        }
        
        if let currentError = error {
            if (currentError as NSError).domain == "NSPOSIXErrorDomain", (currentError as NSError).code == 53 {
                return true
            }
        }
        
        if let httpResponse = request?.response {
            // 4xx
            if httpResponse.statusCodeValue == HTTPStatusCode.notFound ||
                httpResponse.statusCodeValue == HTTPStatusCode.gone
            {
                return true
            }
            
            // 5xx
            if httpResponse.statusCodeValue == HTTPStatusCode.internalServerError ||
                httpResponse.statusCodeValue == HTTPStatusCode.notImplemented ||
                httpResponse.statusCodeValue == HTTPStatusCode.badGateway ||
                httpResponse.statusCodeValue == HTTPStatusCode.serviceUnavailable ||
                httpResponse.statusCodeValue == HTTPStatusCode.gatewayTimeout
            {
                return true
            }
        }
        
        return false
    }
    
    open func shouldRetryRateLimitRequest(_: Error?, request: Request?) -> Bool {
        if isReloadingCancelled || !shouldRetryRateLimit {
            return false
        }
        
        if let httpResponse = request?.response {
            if httpResponse.statusCodeValue == HTTPStatusCode.tooManyRequests {
                return true
            }
        }
        
        return false
    }
}
