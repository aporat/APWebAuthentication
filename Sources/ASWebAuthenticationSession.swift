import Foundation
import SwifterSwift
import UIKit
import AuthenticationServices

// MARK: - ASWebAuthenticationSession Async Support

public extension ASWebAuthenticationSession {

    @MainActor
    static func start(
        url: URL,
        callback: ASWebAuthenticationSession.Callback,
        contextProvider: ASWebAuthenticationPresentationContextProviding,
        ephemeral: Bool = false
    ) async throws(APWebAuthenticationError) -> URL {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(url: url, callback: callback) { callbackURL, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let callbackURL = callbackURL else {
                        continuation.resume(throwing: ASWebAuthenticationSessionError(.canceledLogin))
                        return
                    }

                    continuation.resume(returning: callbackURL)
                }

                session.presentationContextProvider = contextProvider
                session.prefersEphemeralWebBrowserSession = ephemeral

                if !session.start() {
                    continuation.resume(throwing: ASWebAuthenticationSessionError(.canceledLogin))
                }
            }
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw .canceled
        } catch {
            throw .failed(reason: error.localizedDescription)
        }
    }
}

