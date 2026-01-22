import Foundation

// MARK: - Account Type

/// Represents a social media account type/platform.
///
/// An `AccountType` encapsulates the information needed to identify and represent
/// a social media platform in the app. Each type includes:
/// - A unique code (reverse domain identifier)
/// - The platform's web address
/// - A user-facing description/name
///
/// Account types are used throughout the app for:
/// - Identifying which platform an account belongs to
/// - Displaying platform names and links in the UI
/// - Filtering and organizing accounts by platform
/// - Storing user preferences for enabled/disabled platforms
///
/// **Example:**
/// ```swift
/// let instagram = AccountType(
///     code: .instagram,
///     webAddress: "instagram.com",
///     description: "Instagram"
/// )
///
/// print(instagram.description) // "Instagram"
/// print(instagram.fullWebAddress) // "https://instagram.com"
/// ```
///
/// - Note: Account types are immutable value types that conform to `Hashable`,
///         `Identifiable`, and `Sendable` for safe use across the app.
public struct AccountType: Hashable, Identifiable, Sendable {
    
    // MARK: - Properties
    
    /// Unique identifier based on the account code.
    ///
    /// This property satisfies the `Identifiable` protocol and uses the code's
    /// raw value (reverse domain identifier) as the unique ID.
    public var id: String {
        code.rawValue
    }
    
    /// The platform's unique code identifier.
    ///
    /// Uses reverse domain notation (e.g., `com.apple.instagram`) to ensure
    /// uniqueness across platforms.
    public var code: Code
    
    /// The platform's web address (without protocol).
    ///
    /// Examples: `"instagram.com"`, `"x.com"`, `"github.com"`
    ///
    /// - Note: Use `fullWebAddress` to get the complete URL with HTTPS protocol.
    public var webAddress: String
    
    /// User-facing display name for the platform.
    ///
    /// This is the name shown in the UI (e.g., "Instagram", "X", "GitHub").
    public var description: String
    
    // MARK: - Initialization
    
    /// Creates a new account type with the specified properties.
    ///
    /// - Parameters:
    ///   - code: The unique platform code
    ///   - webAddress: The platform's web address (without protocol)
    ///   - description: User-facing platform name
    public init(code: Code, webAddress: String, description: String) {
        self.code = code
        self.webAddress = webAddress
        self.description = description
    }
    
    // MARK: - Computed Properties
    
    /// Returns the full HTTPS web address for the platform.
    ///
    /// This property prepends `https://` to the `webAddress` to create
    /// a complete URL that can be used for opening in a browser.
    ///
    /// **Example:**
    /// ```swift
    /// let instagram = AccountStore.instagram
    /// print(instagram.fullWebAddress) // "https://instagram.com"
    /// ```
    public var fullWebAddress: String {
        "https://\(webAddress)"
    }
    
    /// Returns a URL object for the platform's web address.
    ///
    /// This property creates a URL from the `fullWebAddress` string.
    ///
    /// **Example:**
    /// ```swift
    /// if let url = instagram.url {
    ///     UIApplication.shared.open(url)
    /// }
    /// ```
    ///
    /// - Returns: A URL object, or `nil` if the address is invalid
    public var url: URL? {
        URL(string: fullWebAddress)
    }
    
    // MARK: - Hashable Conformance
    
    /// Hashes the account type based on its unique identifier.
    ///
    /// Two account types with the same code will produce the same hash value,
    /// allowing them to be used in Sets and as Dictionary keys.
    ///
    /// - Parameter hasher: The hasher to combine the ID into
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Compares two account types for equality based on their IDs.
    ///
    /// Two account types are considered equal if they have the same code,
    /// regardless of their web address or description values.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side account type
    ///   - rhs: The right-hand side account type
    ///
    /// - Returns: `true` if both account types have the same ID, `false` otherwise
    public static func == (lhs: AccountType, rhs: AccountType) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Account Type Code

public extension AccountType {
    
    /// Unique identifier codes for supported social media platforms.
    ///
    /// Each code uses reverse domain notation (similar to bundle identifiers)
    /// to ensure global uniqueness. The format is `com.apple.<platform>`.
    ///
    /// **Supported Platforms:**
    /// - Twitter/X
    /// - Instagram
    /// - 500px
    /// - TikTok
    /// - Tumblr
    /// - Twitch
    /// - Pinterest
    /// - Foursquare
    /// - Reddit
    /// - GitHub
    ///
    /// **Usage:**
    /// ```swift
    /// let code = AccountType.Code.instagram
    /// print(code.rawValue) // "com.apple.instagram"
    /// print(code.platformName) // "Instagram"
    /// ```
    ///
    /// - Note: The codes use `com.apple.*` namespace for historical reasons
    ///         and consistency with system account types.
    public enum Code: String, Hashable, Sendable, CaseIterable {
        
        /// Twitter/X platform code
        case twitter = "com.apple.twitter"
        
        /// Instagram platform code
        case instagram = "com.apple.instagram"
        
        /// 500px platform code
        case fiveHundredpx = "com.apple.500px"
        
        /// TikTok platform code
        case tiktok = "com.apple.tiktok"
        
        /// Tumblr platform code
        case tumblr = "com.apple.tumblr"
        
        /// Twitch platform code
        case twitch = "com.apple.twitch"
        
        /// Pinterest platform code
        case pinterest = "com.apple.pinterest"
        
        /// Foursquare platform code
        case foursquare = "com.apple.foursquare"
        
        /// Reddit platform code
        case reddit = "com.apple.reddit"
        
        /// GitHub platform code
        case github = "com.apple.github"
        
        // MARK: - Computed Properties
        
        /// Returns a user-friendly platform name.
        ///
        /// This property extracts the platform name from the reverse domain code
        /// and capitalizes it appropriately.
        ///
        /// **Example:**
        /// ```swift
        /// AccountType.Code.instagram.platformName // "Instagram"
        /// AccountType.Code.fiveHundredpx.platformName // "500px"
        /// ```
        public var platformName: String {
            switch self {
            case .twitter:
                return "Twitter"
            case .instagram:
                return "Instagram"
            case .fiveHundredpx:
                return "500px"
            case .tiktok:
                return "TikTok"
            case .tumblr:
                return "Tumblr"
            case .twitch:
                return "Twitch"
            case .pinterest:
                return "Pinterest"
            case .foursquare:
                return "Foursquare"
            case .reddit:
                return "Reddit"
            case .github:
                return "GitHub"
            }
        }
        
        /// Returns a short identifier for the platform (without domain prefix).
        ///
        /// Extracts just the platform name from the reverse domain identifier.
        ///
        /// **Example:**
        /// ```swift
        /// AccountType.Code.instagram.shortIdentifier // "instagram"
        /// AccountType.Code.fiveHundredpx.shortIdentifier // "500px"
        /// ```
        public var shortIdentifier: String {
            rawValue.replacingOccurrences(of: "com.apple.", with: "")
        }
    }
}
// MARK: - CustomStringConvertible

extension AccountType: CustomStringConvertible {
    
    /// Returns a string representation of the account type.
    ///
    /// Uses the platform's description as the string representation.
    ///
    /// **Example:**
    /// ```swift
    /// let instagram = AccountStore.instagram
    /// print(instagram) // "Instagram"
    /// ```
    public var stringDescription: String {
        description
    }
}

// MARK: - CustomDebugStringConvertible

extension AccountType: CustomDebugStringConvertible {
    
    /// Returns a detailed debug description of the account type.
    ///
    /// Includes the code, web address, and description for debugging purposes.
    ///
    /// **Example:**
    /// ```swift
    /// let instagram = AccountStore.instagram
    /// debugPrint(instagram)
    /// // AccountType(code: com.apple.instagram, webAddress: instagram.com, description: Instagram)
    /// ```
    public var debugDescription: String {
        "AccountType(code: \(code.rawValue), webAddress: \(webAddress), description: \(description))"
    }
}

