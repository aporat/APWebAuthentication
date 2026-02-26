import Foundation
import SwifterSwift
@preconcurrency import SwiftyUserDefaults
import UIKit

// MARK: - User Defaults Keys

/// User defaults keys for storing enabled/disabled state of social media services.
extension DefaultsKeys {

    var Instagram: DefaultsKey<Bool> {
        .init("kServiceInstagram", defaultValue: false)
    }

    var Twitter: DefaultsKey<Bool> {
        .init("kServiceTwitter", defaultValue: false)
    }

    var Pinterest: DefaultsKey<Bool> {
        .init("kServicePinterest", defaultValue: false)
    }

    var Tumblr: DefaultsKey<Bool> {
        .init("kServiceTumblr", defaultValue: false)
    }

    var Foursquare: DefaultsKey<Bool> {
        .init("kServiceFoursquare", defaultValue: false)
    }

    var Reddit: DefaultsKey<Bool> {
        .init("kServiceReddit", defaultValue: false)
    }

    var Github: DefaultsKey<Bool> {
        .init("kServiceGithub", defaultValue: false)
    }

    var Twitch: DefaultsKey<Bool> {
        .init("kServiceTwitch", defaultValue: false)
    }

    var FiveHundredpx: DefaultsKey<Bool> {
        .init("kServiceFiveHundredpx", defaultValue: false)
    }

    var TikTok: DefaultsKey<Bool> {
        .init("kServiceTikTok", defaultValue: false)
    }
}

// MARK: - AccountType.Code + Defaults

private extension AccountType.Code {

    /// Maps an account type code to its corresponding user defaults key.
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
/// Provides static definitions for platforms, filtering based on user preferences,
/// and lookup by account code.
///
/// **Example Usage:**
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

    public static let instagram = AccountType(
        code: .instagram,
        webAddress: "instagram.com",
        description: "Instagram"
    )

    public static let twitter = AccountType(
        code: .twitter,
        webAddress: "x.com",
        description: "X"
    )

    public static let pinterest = AccountType(
        code: .pinterest,
        webAddress: "pinterest.com",
        description: "Pinterest"
    )

    public static let tumblr = AccountType(
        code: .tumblr,
        webAddress: "tumblr.com",
        description: "Tumblr"
    )

    public static let twitch = AccountType(
        code: .twitch,
        webAddress: "twitch.tv",
        description: "Twitch"
    )

    public static let reddit = AccountType(
        code: .reddit,
        webAddress: "reddit.com",
        description: "Reddit"
    )

    public static let foursquare = AccountType(
        code: .foursquare,
        webAddress: "foursquare.com",
        description: "Foursquare"
    )

    public static let github = AccountType(
        code: .github,
        webAddress: "github.com",
        description: "GitHub"
    )

    public static let fiveHundredpx = AccountType(
        code: .fiveHundredpx,
        webAddress: "500px.com",
        description: "500px"
    )

    public static let tiktok = AccountType(
        code: .tiktok,
        webAddress: "tiktok.com",
        description: "TikTok"
    )

    // MARK: - Account Type Collections

    /// Complete list of all supported account types.
    ///
    /// Order determines display order in UI (settings, account lists).
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
    /// Filters based on user preferences stored in UserDefaults.
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
    /// - Parameter code: The account type code to search for
    /// - Returns: The matching account type, or nil if not found
    public static func accountType(for code: AccountType.Code) -> AccountType? {
        all.first { $0.code == code }
    }

    /// Checks if a specific account type is enabled by the user.
    ///
    /// - Parameter code: The account type code to check
    /// - Returns: True if enabled, false otherwise
    @MainActor
    public static func isEnabled(_ code: AccountType.Code) -> Bool {
        guard let key = code.defaultsKey else {
            return false
        }
        return Defaults[key: key]
    }

    /// Enables or disables a specific account type.
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

    private init() {}
}
