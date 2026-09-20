import Foundation
import UIKit
import AuthenticationServices

// MARK: - ASWebAuthenticationSession Async Support

@MainActor
private final class ASWebAuthSessionHolder {
    var session: ASWebAuthenticationSession?
}

public extension ASWebAuthenticationSession {

    /// Starts a session that completes when the browser redirects to a URL
    /// matching `callback`.
    ///
    /// `ASWebAuthenticationSession.Callback` requires iOS 17.4. On earlier
    /// iOS 17 releases use `start(url:callbackURLScheme:contextProvider:ephemeral:)`.
    @available(iOS 17.4, *)
    @MainActor
    static func start(
        url: URL,
        callback: ASWebAuthenticationSession.Callback,
        contextProvider: ASWebAuthenticationPresentationContextProviding,
        ephemeral: Bool = false
    ) async throws(APWebAuthenticationError) -> URL {
        try await run(
            contextProvider: contextProvider,
            ephemeral: ephemeral
        ) { completion in
            ASWebAuthenticationSession(url: url, callback: callback, completionHandler: completion)
        }
    }

    /// Starts a session that completes when the browser redirects to a URL
    /// with the given custom scheme. Works on every supported iOS version.
    @MainActor
    static func start(
        url: URL,
        callbackURLScheme: String,
        contextProvider: ASWebAuthenticationPresentationContextProviding,
        ephemeral: Bool = false
    ) async throws(APWebAuthenticationError) -> URL {
        try await run(
            contextProvider: contextProvider,
            ephemeral: ephemeral
        ) { completion in
            ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completion)
        }
    }

    @MainActor
    private static func run(
        contextProvider: ASWebAuthenticationPresentationContextProviding,
        ephemeral: Bool,
        makeSession: (@escaping ASWebAuthenticationSession.CompletionHandler) -> ASWebAuthenticationSession
    ) async throws(APWebAuthenticationError) -> URL {
        // Holds the session alive for the duration of the presentation. The
        // `defer` releases it once `run` returns — i.e. after the continuation
        // has resumed — which keeps every touch of `holder` on the main actor.
        // Clearing it from inside the completion handler instead would mean
        // asserting main-actor isolation on a callback Apple never promises to
        // deliver on the main thread, and `assumeIsolated` traps when it isn't.
        let holder = ASWebAuthSessionHolder()
        defer { holder.session = nil }

        do {
            return try await withCheckedThrowingContinuation { continuation in
                let session = makeSession { callbackURL, error in
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
