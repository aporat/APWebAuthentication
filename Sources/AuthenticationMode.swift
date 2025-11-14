import Foundation

public enum AuthenticationMode: String, Sendable {
    case `private`
    case explicit
    case implicit
    case web
    case browser
    case app
    
    public init?(_ string: String?) {
        guard let rawValue = string else {
            return nil
        }
        
        self.init(rawValue: rawValue)
    }
}
