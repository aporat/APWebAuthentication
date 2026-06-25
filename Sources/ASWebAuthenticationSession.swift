import Foundation
import SwifterSwift
import UIKit
import AuthenticationServices

// MARK: - ASWebAuthenticationSession Async Support

@MainActor
private final class ASWebAuthSessionHolder {
    var session: ASWebAuthenticationSession?
}

public extension ASWebAuthenticationSession {

    @MainActor
    static func start(
        url: URL,
        callback: ASWebAuthenticationSession.Callback,
        contextProvider: ASWebAuthenticationPresentationContextProviding,
        ephemeral: Bool = false
    ) async throws(APWebAuthenticationError) -> URL {
        let holder = ASWebAuthSessionHolder()
        do {
            return try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(url: url, callback: callback) { callbackURL, error in
                    MainActor.assumeIsolated {
                        holder.session = nil
                    }
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
                holder.session = session

                if !session.start() {
                    holder.session = nil
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
