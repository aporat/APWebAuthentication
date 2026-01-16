import Foundation
@preconcurrency import SwiftyJSON

// MARK: - TumblrBlog

public final class TumblrBlog: GenericUser, @unchecked Sendable {
    
    // MARK: - Properties
    
    public var name: String?
    public var postsCount: Int32 = 0
    
    // MARK: - Initialization
    
    public required init?(info: JSON) {
        // Try UUID-based initialization first (modern API response)
        if let uuid = info["uuid"].string, !uuid.isEmpty {
            let username = Self.parseUsername(from: info["url"].string)
            let fullname = info["name"].string ?? info["title"].string
            
            // Try to get avatar from avatar array, fallback to API endpoint
            var avatarURL: URL?
            if let avatarArray = info["avatar"].array,
               let avatar64 = avatarArray.first(where: { $0["width"].int == 64 }),
               let avatar64UrlString = avatar64["url"].string {
                avatarURL = URL(string: avatar64UrlString)
            } else {
                avatarURL = URL(string: "https://api.tumblr.com/v2/blog/\(uuid)/avatar")
            }
            
            super.init(
                userId: uuid,
                username: username,
                fullname: fullname,
                avatarPicture: avatarURL
            )
            
            // Set blog metrics
            self.postsCount = info["posts"].int32 ?? 0
            self.followersCount = info["followers"].int32 ?? 0
            
        // Fallback to name-based initialization (legacy API response)
        } else if let name = info["name"].string, !name.isEmpty, let urlString = info["url"].string {
            let userId = name
            let username = name
            let fullname = name
            
            // Generate avatar URL from blog host
            var avatarURL: URL?
            if let host = URL(string: urlString)?.host {
                avatarURL = URL(string: "https://api.tumblr.com/v2/blog/\(host)/avatar")
            }
            
            super.init(
                userId: userId,
                username: username,
                fullname: fullname,
                avatarPicture: avatarURL
            )
            
            self.postsCount = 0
            self.followersCount = 0
            
        } else {
            return nil
        }
        
        self.name = info["name"].string ?? info["title"].string
    }
    
    // MARK: - Helper Methods
    
    /// Parses username from Tumblr blog URL
    /// - Parameter urlString: The blog URL string
    /// - Returns: Extracted username or nil
    private static func parseUsername(from urlString: String?) -> String? {
        guard let urlString else { return nil }
        
        // Try URL parsing first
        if let url = URL(string: urlString) {
            // Handle www.tumblr.com/blog URLs
            if url.host?.contains("www.tumblr.com") == true, url.pathComponents.count > 2 {
                return url.pathComponents.last
            }
            // Handle subdomain.tumblr.com URLs
            else if let host = url.host, host.contains(".tumblr.com") {
                return host.replacingOccurrences(of: ".tumblr.com", with: "")
            }
        }
        
        // Fallback to string manipulation
        return urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.tumblr.com/blog/view/", with: "")
            .replacingOccurrences(of: "tumblr.com/", with: "tumblr.com")
            .split(separator: ".").first.map(String.init)
    }
}
