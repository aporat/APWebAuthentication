import UIKit

public struct AccountType: Sendable {
    public enum Code: String, Sendable {
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
        case parler = "com.apple.parler"
        case googleplus = "com.apple.googleplus"
    }

    public var code: AccountType.Code
    public var webAddress: String
    public var description: String
    public var color: UIColor

    init(code: AccountType.Code, webAddress: String, description: String, color: UIColor) {
        self.code = code
        self.webAddress = webAddress
        self.description = description
        self.color = color
    }
}
