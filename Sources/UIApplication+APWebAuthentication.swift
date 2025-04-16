import Foundation
import UIKit

extension UIApplication {
    
    var shortAppName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
    }
}
