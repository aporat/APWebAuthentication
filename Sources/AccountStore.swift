import Foundation
import SwifterSwift
import UIKit

// MARK: - Account Store

/// Central registry for all supported social media account types.
///
/// Provides static definitions for platforms, filtering based on enabled/disabled state,
/// and lookup by account code.
///
/// **Example Usage:**
/// ```swift
/// // Enable specific platforms
/// AccountStore.setEnabled(.instagram, enabled: true)
/// AccountStore.setEnabled(.twitter, enabled: true)
///
/// // Get all supported platforms
/// let allPlatforms = AccountStore.all
///
/// // Get only enabled platforms
/// let enabledPlatforms = AccountStore.accountTypes
///
/// // Check if a platform is enabled
/// if AccountStore.isEnabled(.instagram) {
///     print("Instagram is enabled")
/// }
/// ```
@MainActor
public final class AccountStore {
    
    // MARK: - Configuration
    
    /// Set of currently enabled account type codes.
    private static var enabledCodes: Set<AccountType.Code> = []
    
    /// Enables or disables a specific account type.
    ///
    /// - Parameters:
    ///   - code: The account type code to update
    ///   - enabled: Whether to enable or disable the account type
    public static func setEnabled(_ code: AccountType.Code, enabled: Bool) {
        if enabled {
            enabledCodes.insert(code)
        } else {
            enabledCodes.remove(code)
        }
    }
    
    /// Enables multiple account types at once.
    ///
    /// - Parameter codes: The account type codes to enable
    public static func enable(_ codes: AccountType.Code...) {
        enabledCodes.formUnion(codes)
    }
    
    /// Disables multiple account types at once.
    ///
    /// - Parameter codes: The account type codes to disable
    public static func disable(_ codes: AccountType.Code...) {
        enabledCodes.subtract(codes)
    }
    
    /// Enables all account types.
    public static func enableAll() {
        enabledCodes = Set(AccountType.Code.allCases)
    }
    
    /// Disables all account types.
    public static func disableAll() {
        enabledCodes.removeAll()
    }

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

    /// List of account types that are currently enabled.
    ///
    /// Filters based on the enabled codes set.
    public static var accountTypes: [AccountType] {
        all.filter { enabledCodes.contains($0.code) }
    }

    // MARK: - Lookup Methods

    /// Finds an account type by its code.
    ///
    /// - Parameter code: The account type code to search for
    /// - Returns: The matching account type, or nil if not found
    public static func accountType(for code: AccountType.Code) -> AccountType? {
        all.first { $0.code == code }
    }

    /// Checks if a specific account type is enabled.
    ///
    /// - Parameter code: The account type code to check
    /// - Returns: True if enabled, false otherwise
    public static func isEnabled(_ code: AccountType.Code) -> Bool {
        enabledCodes.contains(code)
    }

    // MARK: - Initialization

    private init() {}
}
