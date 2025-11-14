import Foundation
import UIKit
import Alamofire
import HTTPStatusCodes

open class AuthClientRequestRetrier: RequestRetrier, @unchecked Sendable {
    
    // REFACTOR: Use a lock to protect all mutable state.
    // This class is nonisolated and can be called from any thread,
    // so we must prevent data races on its properties.
    private let stateLock = NSLock()

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
    
    // This method is nonisolated.
    open func retry(_ request: Request, for _: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        
        // Property access is now thread-safe via the lock.
        if isReloadingCancelled {
            completion(.doNotRetry)
            return
        }
        
        // This wrapper is a great solution for the Sendable warning.
        final class CompletionWrapper: @unchecked Sendable {
            let closure: (RetryResult) -> Void
            
            init(_ closure: @escaping (RetryResult) -> Void) {
                self.closure = closure
            }
            
            func callAsFunction(_ result: RetryResult) {
                closure(result)
            }
        }
        
        // Wrap the non-Sendable closure in our Sendable wrapper
        let safeCompletion = CompletionWrapper(completion)
        
        // Method calls are now thread-safe as they use the locked properties.
        if shouldRetryRequest(error, request: request) {
            
            // Property access is now thread-safe.
            if request.retryCount >= maxRetryCount {
                safeCompletion(.doNotRetry) // <-- Use wrapper
                return
            }
            
            // BUG FIX: Use the `retryWaitSeconds` variable instead of 1.0
            safeCompletion(.retryWithDelay(retryWaitSeconds)) // <-- Use wrapper
            return
            
        } else if shouldRetryRateLimitRequest(error, request: request) {
            
            // Property access is now thread-safe.
            let initialAutoRetry = rateLimitWaitSeconds * (Int(request.retryCount) + 1)
            
            // REFACTOR: Use a single @MainActor Task for all UI and async logic.
            // This replaces the `DispatchQueue.main.async` and `Timer`.
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                var autoRetry = initialAutoRetry
                var countdownTask: Task<Void, Error>? = nil // Task handle to cancel
                
                let title = NSLocalizedString("Rate Limit Exceeded", comment: "")
                let message = String(format: "You have made too many requests. If you do nothing, the app will retry automatically in %d seconds.", autoRetry)
                let actionSheetController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                
                actionSheetController.addAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                    NotificationCenter.default.post(name: AuthClient.didRateLimitCancelled, object: nil, userInfo: nil)
                    
                    countdownTask?.cancel() // Cancel the countdown task
                    safeCompletion(.doNotRetry) // <-- Use wrapper
                    return
                }
                
                // All property access here is now thread-safe via the lock.
                if request.retryCount >= 3 || self.shouldAlwaysShowLoginAgain {
                    actionSheetController.addAction(title: NSLocalizedString("Login Again", comment: ""), style: .default) { [weak self] _ in
                        guard let self = self, !self.isReloadingCancelled else {
                            return
                        }
                        
                        NotificationCenter.default.post(name: AuthClient.didRateLimitSessionExpired, object: nil, userInfo: nil)
                        
                        countdownTask?.cancel() // Cancel the countdown task
                        safeCompletion(.doNotRetryWithError(APWebAuthenticationError.canceled)) // <-- Use wrapper
                        return
                    }
                }
                
                actionSheetController.addAction(title: NSLocalizedString("Retry Now", comment: ""), style: .default) { [weak self] _ in
                    guard let self = self, !self.isReloadingCancelled else {
                        return
                    }
                    
                    countdownTask?.cancel() // Cancel the countdown task
                    safeCompletion(.retry) // <-- Use wrapper
                    return
                }
                
                actionSheetController.preferredAction = actionSheetController.actions[actionSheetController.actions.count - 1]
                
                if let rootVC = UIApplication.shared.keyWindow?.rootViewController, rootVC.presentedViewController == nil {
                     rootVC.present(actionSheetController, animated: true)
                } else {
                    print("⚠️ AuthClientRequestRetrier: Could not present rate limit alert.")
                }
                
                // REFACTOR: This is the new async countdown loop, replacing the Timer.
                // It is fully @MainActor-isolated and safe.
                countdownTask = Task { @MainActor in
                    while autoRetry > 0 {
                        // 1. Wait for 1 second
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        
                        // 2. Check if a button press cancelled the task
                        try Task.checkCancellation()
                        
                        // 3. Decrement and update UI
                        autoRetry -= 1
                        
                        if autoRetry == 0 {
                            // This is now safe, as we are on the MainActor
                            actionSheetController.dismiss(animated: true)
                            safeCompletion(.retryWithDelay(0.1)) // <-- Use wrapper
                        } else {
                            // This is also safe
                            actionSheetController.message = String(format: "You have made too many requests. If you do nothing, the app will retry automatically in %d seconds.", autoRetry)
                        }
                    }
                }
            }
            
            return
        }
        
        safeCompletion(.doNotRetry)
    }
    
    // This method is nonisolated.
    open func shouldRetryRequest(_ error: Error?, request: Request?) -> Bool {
        // Property access is now thread-safe.
        if isReloadingCancelled {
            return false
        }
        
        // This logic is clean and uses the `isConnectionError` extension.
        if error?.isConnectionError == true {
            return true
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
    
    // This method is nonisolated.
    open func shouldRetryRateLimitRequest(_: Error?, request: Request?) -> Bool {
        // Property access is now thread-safe.
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

// REFACTOR: `UIApplication.shared.keyWindow` is deprecated.
// This extension provides a modern, safe way to get the active window scene.
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
