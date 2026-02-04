import Foundation
import SwifterSwift
@preconcurrency import SwiftyUserDefaults
import UIKit

// MARK: - User Defaults Keys

/// User defaults keys for storing enabled/disabled state of social media services.
///
/// Each key corresponds to a social media platform and stores a boolean indicating
/// whether the user has enabled that service in the app's settings.
///
/// **Key Format:** `kService<PlatformName>`
///
/// **Default Value:** All services default to `false` (disabled)
public extension DefaultsKeys {

    /// Instagram service enabled state
    var Instagram: DefaultsKey<Bool> {
        .init("kServiceInstagram", defaultValue: false)
    }

    /// Twitter/X service enabled state
    var Twitter: DefaultsKey<Bool> {
        .init("kServiceTwitter", defaultValue: false)
    }

    /// Pinterest service enabled state
    var Pinterest: DefaultsKey<Bool> {
        .init("kServicePinterest", defaultValue: false)
    }

    /// Tumblr service enabled state
    var Tumblr: DefaultsKey<Bool> {
        .init("kServiceTumblr", defaultValue: false)
    }

    /// Foursquare service enabled state
    var Foursquare: DefaultsKey<Bool> {
        .init("kServiceFoursquare", defaultValue: false)
    }

    /// Reddit service enabled state
    var Reddit: DefaultsKey<Bool> {
        .init("kServiceReddit", defaultValue: false)
    }

    /// GitHub service enabled state
    var Github: DefaultsKey<Bool> {
        .init("kServiceGithub", defaultValue: false)
    }

    /// Twitch service enabled state
    var Twitch: DefaultsKey<Bool> {
        .init("kServiceTwitch", defaultValue: false)
    }

    /// 500px service enabled state
    var FiveHundredpx: DefaultsKey<Bool> {
        .init("kServiceFiveHundredpx", defaultValue: false)
    }

    /// TikTok service enabled state
    var TikTok: DefaultsKey<Bool> {
        .init("kServiceTikTok", defaultValue: false)
    }
}

// MARK: - AccountType.Code + Defaults

private extension AccountType.Code {

    /// Maps an account type code to its corresponding user defaults key.
    ///
    /// This computed property provides a centralized mapping between account codes
    /// and their persistence keys in UserDefaults.
    ///
    /// - Returns: The defaults key for this account type, or `nil` if not supported
    var defaultsKey: DefaultsKey<Bool>? {
        switch self {
        case .instagram:
            return .init("kServiceInstagram", defaultValue: false)
        case .twitter:
            return .init("kServiceTwitter", defaultValue: false)
        case .pinterest:
            return .init("kServicePinterest", defaultValue: false)
        case .tumblr:
            return .init("kServiceTumblr", defaultValue: false)
        case .twitch:
            return .init("kServiceTwitch", defaultValue: false)
        case .reddit:
            return .init("kServiceReddit", defaultValue: false)
        case .foursquare:
            return .init("kServiceFoursquare", defaultValue: false)
        case .github:
            return .init("kServiceGithub", defaultValue: false)
        case .fiveHundredpx:
            return .init("kServiceFiveHundredpx", defaultValue: false)
        case .tiktok:
            return .init("kServiceTikTok", defaultValue: false)
        }
    }
}

// MARK: - Account Store

/// Central registry for all supported social media account types.
///
/// `AccountStore` provides:
/// - Static definitions for all supported platforms
/// - Complete list of available account types
/// - Filtering based on user preferences (enabled/disabled)
/// - Lookup by account code
///
/// **Supported Platforms:**
/// - Instagram
/// - Twitter/X
/// - Pinterest
/// - Tumblr
/// - Twitch
/// - Reddit
/// - Foursquare
/// - GitHub
/// - 500px
/// - TikTok
///
/// **Usage:**
/// ```swift
/// // Get all supported platforms
/// let allPlatforms = AccountStore.all
///
/// // Get only enabled platforms
/// let enabledPlatforms = await AccountStore.accountTypes
///
/// // Look up specific platform
/// if let instagram = AccountStore.accountType(for: .instagram) {
///     print(instagram.description)
/// }
/// ```
public final class AccountStore {

    // MARK: - Account Type Definitions

    /// Instagram account type configuration
    public static let instagram = AccountType(
        code: .instagram,
        webAddress: "instagram.com",
        description: "Instagram"
    )

    /// Twitter/X account type configuration
    public static let twitter = AccountType(
        code: .twitter,
        webAddress: "x.com",
        description: "X"
    )

    /// Pinterest account type configuration
    public static let pinterest = AccountType(
        code: .pinterest,
        webAddress: "pinterest.com",
        description: "Pinterest"
    )

    /// Tumblr account type configuration
    public static let tumblr = AccountType(
        code: .tumblr,
        webAddress: "tumblr.com",
        description: "Tumblr"
    )

    /// Twitch account type configuration
    public static let twitch = AccountType(
        code: .twitch,
        webAddress: "twitch.tv",
        description: "Twitch"
    )

    /// Reddit account type configuration
    public static let reddit = AccountType(
        code: .reddit,
        webAddress: "reddit.com",
        description: "Reddit"
    )

    /// Foursquare account type configuration
    public static let foursquare = AccountType(
        code: .foursquare,
        webAddress: "foursquare.com",
        description: "Foursquare"
    )

    /// GitHub account type configuration
    public static let github = AccountType(
        code: .github,
        webAddress: "github.com",
        description: "GitHub"
    )

    /// 500px account type configuration
    public static let fiveHundredpx = AccountType(
        code: .fiveHundredpx,
        webAddress: "500px.com",
        description: "500px"
    )

    /// TikTok account type configuration
    public static let tiktok = AccountType(
        code: .tiktok,
        webAddress: "tiktok.com",
        description: "TikTok"
    )

    // MARK: - Account Type Collections

    /// Complete list of all supported account types.
    ///
    /// This array contains all social media platforms that the app supports,
    /// regardless of whether they are currently enabled by the user.
    ///
    /// The order of platforms in this array determines their display order
    /// in the UI (e.g., settings screens, account lists).
    public static let all: [AccountType] = [
        instagram,
        twitter,
        pinterest,
        tumblr,
        twitch,
        reddit,
        foursquare,
        github,
        fiveHundredpx,
        tiktok
    ]

    /// List of account types that are currently enabled by the user.
    ///
    /// This computed property filters the complete list of account types based on
    /// the user's preferences stored in UserDefaults. Only platforms that the user
    /// has explicitly enabled in settings will be returned.
    ///
    /// - Note: This property must be accessed from the main actor because it reads
    ///         from UserDefaults, which should only be accessed from the main thread.
    ///
    /// - Returns: An array of enabled account types, in the same order as `all`
    @MainActor
    public static var accountTypes: [AccountType] {
        all.filter { type in
            guard let key = type.code.defaultsKey else {
                return false
            }
            return Defaults[key: key]
        }
    }

    // MARK: - Lookup Methods

    /// Finds an account type by its code.
    ///
    /// This method searches the complete list of supported platforms for one
    /// matching the given code.
    ///
    /// **Example:**
    /// ```swift
    /// if let instagram = AccountStore.accountType(for: .instagram) {
    ///     print("Found: \(instagram.description)")
    ///     print("Website: \(instagram.webAddress)")
    /// }
    /// ```
    ///
    /// - Parameter code: The account type code to search for
    /// - Returns: The matching account type, or `nil` if not found
    public static func accountType(for code: AccountType.Code) -> AccountType? {
        all.first { $0.code == code }
    }

    /// Checks if a specific account type is enabled by the user.
    ///
    /// This is a convenience method that checks the UserDefaults value for
    /// the given account code.
    ///
    /// - Parameter code: The account type code to check
    /// - Returns: `true` if the account type is enabled, `false` otherwise
    @MainActor
    public static func isEnabled(_ code: AccountType.Code) -> Bool {
        guard let key = code.defaultsKey else {
            return false
        }
        return Defaults[key: key]
    }

    /// Enables or disables a specific account type.
    ///
    /// This method updates the UserDefaults value for the given account code,
    /// which will affect the results of `accountTypes` and `isEnabled()`.
    ///
    /// - Parameters:
    ///   - code: The account type code to update
    ///   - enabled: Whether to enable or disable the account type
    @MainActor
    public static func setEnabled(_ code: AccountType.Code, enabled: Bool) {
        guard let key = code.defaultsKey else {
            return
        }
        Defaults[key: key] = enabled
    }

    // MARK: - Initialization

    /// Private initializer to prevent instantiation.
    ///
    /// `AccountStore` is designed as a namespace for static properties and methods only.
    private init() {}
}
