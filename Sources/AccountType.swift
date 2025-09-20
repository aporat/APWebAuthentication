import Foundation

public struct AccountType: Hashable, Identifiable, Sendable {
    
    public var id: String { self.code.rawValue }

    public struct Code: RawRepresentable, Hashable, Sendable, CaseIterable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let twitter = Code(rawValue: "com.apple.twitter")
        public static let instagram = Code(rawValue: "com.apple.instagram")
        public static let fiveHundredpx = Code(rawValue: "com.apple.500px")
        public static let tiktok = Code(rawValue: "com.apple.tiktok")
        public static let tumblr = Code(rawValue: "com.apple.tumblr")
        public static let twitch = Code(rawValue: "com.apple.twitch")
        public static let pinterest = Code(rawValue: "com.apple.pinterest")
        public static let foursquare = Code(rawValue: "com.apple.foursquare")
        public static let reddit = Code(rawValue: "com.apple.reddit")
        public static let github = Code(rawValue: "com.apple.github")
        public static let parler = Code(rawValue: "com.apple.parler")
        public static let googleplus = Code(rawValue: "com.apple.googleplus")
        
        public static var allCases: [Code] = [
                    .twitter, .instagram, .fiveHundredpx, .tiktok, .tumblr, .twitch,
                    .pinterest, .foursquare, .reddit, .github, .parler, .googleplus
                ]
    }

    public var code: AccountType.Code
    public var webAddress: String
    public var description: String

    init?(code: AccountType.Code, webAddress: String, description: String) {
        guard Code.allCases.contains(code) else {
            return nil
        }
        
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

