import Foundation

// MARK: - AccountType
public struct AccountType: Hashable, Identifiable, Sendable {
    
    public var id: String { self.code.rawValue }
    
    public var code: AccountType.Code
    public var webAddress: String
    public var description: String
    
    public init(code: AccountType.Code, webAddress: String, description: String) {
        self.code = code
        self.webAddress = webAddress
        self.description = description
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: AccountType, rhs: AccountType) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AccountType.Code
public extension AccountType {
    
    enum Code: String, Hashable, Sendable, CaseIterable {
        case twitter = "com.apple.twitter"
        case instagram = "com.apple.instagram"
        case fiveHundredpx = "com.apple.500px"
        case tiktok = "com.apple.tiktok"
        case tumblr = "com.apple.tumblr"
        case twitch = "com.apple.twitch"
        case pinterest = "com.apple.pinterest"
        case foursquare = "com.apple.foursquare"
        case reddit = "com.apple.reddit"
        case github = "com.apple.github"
    }
}
