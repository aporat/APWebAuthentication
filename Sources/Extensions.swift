import Foundation
import UIKit

extension Data {
    var allBytes: [UInt8] {
        [UInt8](self)
    }
}


extension UIApplication {
    
    var shortAppName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
    }
}
