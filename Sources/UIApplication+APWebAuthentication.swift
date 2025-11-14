import Foundation
import UIKit

@MainActor
public extension UIApplication {
    
    /// A safe method to get the app's display name from the Info.plist.
    /// This is correctly isolated to the @MainActor.
    var shortAppName: String {
        guard let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String else {
            
            if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
                return bundleName
            }
            
            return ""
        }
        
        return displayName
    }
}
