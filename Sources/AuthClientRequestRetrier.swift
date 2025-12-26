import Foundation
import UIKit
import Alamofire
import HTTPStatusCodes

open class AuthClientRequestRetrier: RequestRetrier, @unchecked Sendable {
    
    private let stateLock = NSLock()
    
    private var _isRateLimitAlertVisible = false
    
    private var _maxRetryCount: UInt = 5
    fileprivate var maxRetryCount: UInt {
        get { stateLock.withLock { _maxRetryCount } }
        set { stateLock.withLock { _maxRetryCount = newValue } }
    }
    
    private var _retryWaitSeconds: TimeInterval = 1.0
    fileprivate var retryWaitSeconds: TimeInterval {
        get { stateLock.withLock { _retryWaitSeconds } }
        set { stateLock.withLock { _retryWaitSeconds = newValue } }
    }
    
    private var _rateLimitWaitSeconds: Int = 60
    fileprivate var rateLimitWaitSeconds: Int {
        get { stateLock.withLock { _rateLimitWaitSeconds } }
        set { stateLock.withLock { _rateLimitWaitSeconds = newValue } }
    }
    
    private var _isReloadingCancelled = false
    open var isReloadingCancelled: Bool {
        get { stateLock.withLock { _isReloadingCancelled } }
        set { stateLock.withLock { _isReloadingCancelled = newValue } }
    }
    
    private var _shouldRetryRateLimit = false
    open var shouldRetryRateLimit: Bool {
        get { stateLock.withLock { _shouldRetryRateLimit } }
        set { stateLock.withLock { _shouldRetryRateLimit = newValue } }
    }
    
    private var _shouldAlwaysShowLoginAgain = false
    var shouldAlwaysShowLoginAgain: Bool {
        get { stateLock.withLock { _shouldAlwaysShowLoginAgain } }
        set { stateLock.withLock { _shouldAlwaysShowLoginAgain = newValue } }
    }
    
    public init() {
        
    }
    
    open func retry(_ request: Request, for _: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        
        if isReloadingCancelled {
            completion(.doNotRetry)
            return
        }
        
        final class CompletionWrapper: @unchecked Sendable {
            let closure: (RetryResult) -> Void
            
            init(_ closure: @escaping (RetryResult) -> Void) {
                self.closure = closure
            }
            
            func callAsFunction(_ result: RetryResult) {
                closure(result)
            }
        }
        
        let safeCompletion = CompletionWrapper(completion)
        
        if shouldRetryRequest(error, request: request) {
            
            if request.retryCount >= maxRetryCount {
                safeCompletion(.doNotRetry)
                return
            }
            
            safeCompletion(.retryWithDelay(retryWaitSeconds))
            return
            
        } else if shouldRetryRateLimitRequest(error, request: request) {
            
            stateLock.lock()
            if _isRateLimitAlertVisible {
                stateLock.unlock()
                safeCompletion(.retryWithDelay(1.0))
                return
            }
            _isRateLimitAlertVisible = true
            stateLock.unlock()
            
            let initialAutoRetry = rateLimitWaitSeconds * (Int(request.retryCount) + 1)
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                var autoRetry = initialAutoRetry
                var countdownTask: Task<Void, Error>? = nil
                
                let cleanup = {
                    self.stateLock.withLock { self._isRateLimitAlertVisible = false }
                }
                
                let title = NSLocalizedString("Rate Limit Exceeded", comment: "")
                let message = String(format: "You have made too many requests. If you do nothing, the app will retry automatically in %d seconds.", autoRetry)
                let actionSheetController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                
                actionSheetController.addAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                    cleanup()
                    NotificationCenter.default.post(name: AuthClient.didRateLimitCancelled, object: nil, userInfo: nil)
                    
                    countdownTask?.cancel()
                    safeCompletion(.doNotRetry)
                    return
                }
                
                if request.retryCount >= 3 || self.shouldAlwaysShowLoginAgain {
                    actionSheetController.addAction(title: NSLocalizedString("Login Again", comment: ""), style: .default) { [weak self] _ in
                        cleanup()
                        guard let self = self, !self.isReloadingCancelled else {
                            return
                        }
                        
                        NotificationCenter.default.post(name: AuthClient.didRateLimitSessionExpired, object: nil, userInfo: nil)
                        
                        countdownTask?.cancel()
                        safeCompletion(.doNotRetryWithError(APWebAuthenticationError.canceled))
                        return
                    }
                }
                
                actionSheetController.addAction(title: NSLocalizedString("Retry Now", comment: ""), style: .default) { [weak self] _ in
                    cleanup()
                    guard let self = self, !self.isReloadingCancelled else {
                        return
                    }
                    
                    countdownTask?.cancel()
                    safeCompletion(.retry)
                    return
                }
                
                actionSheetController.preferredAction = actionSheetController.actions[actionSheetController.actions.count - 1]
                
                if let keyWindow = UIApplication.shared.keyWindow,
                   var topController = keyWindow.rootViewController {
                    
                    while let presented = topController.presentedViewController {
                        if presented.isBeingDismissed { break }
                        topController = presented
                    }
                    
                    topController.present(actionSheetController, animated: true)
                    
                } else {
                    print("⚠️ AuthClientRequestRetrier: Could not present rate limit alert.")
                    cleanup()
                    safeCompletion(.doNotRetry) // Fail safely if UI cannot appear
                    return
                }
                
                countdownTask = Task { @MainActor in
                    while autoRetry > 0 {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        
                        try Task.checkCancellation()
                        
                        autoRetry -= 1
                        
                        if autoRetry == 0 {
                            cleanup()
                            actionSheetController.dismiss(animated: true)
                            safeCompletion(.retryWithDelay(0.1))
                        } else {
                            actionSheetController.message = String(format: "You have made too many requests. If you do nothing, the app will retry automatically in %d seconds.", autoRetry)
                        }
                    }
                }
            }
            
            return
        }
        
        safeCompletion(.doNotRetry)
    }
    
    open func shouldRetryRequest(_ error: Error?, request: Request?) -> Bool {
        if isReloadingCancelled {
            return false
        }
        
        if error?.isConnectionError == true {
            return true
        }
        
        if let currentError = error {
            if (currentError as NSError).domain == "NSPOSIXErrorDomain", (currentError as NSError).code == 53 {
                return true
            }
        }
        
        if let httpResponse = request?.response {
            if httpResponse.statusCodeValue == HTTPStatusCode.notFound ||
                httpResponse.statusCodeValue == HTTPStatusCode.gone
            {
                return true
            }
            
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

@MainActor
private extension UIApplication {
    var keyWindow: UIWindow? {
        self.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
    }
}
