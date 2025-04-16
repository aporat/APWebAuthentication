import Foundation
import SwiftyJSON

public extension JSON {
    var idString: String? {
        if let stringIDValue = string, !stringIDValue.isEmpty {
            return stringIDValue
        } else if let id = int64, id != 0 {
            return String(id)
        } else if let id = int, id != 0 {
            return String(id)
        }

        return nil
    }

    var int32Number: Int32? {
        if let value = int32 {
            return value
        } else if let value = int {
            return Int32(value)
        } else if let value = string?.int {
            return Int32(value)
        }

        return nil
    }

    var date: Date? {
        if let createdTime = double, createdTime > 0 {
            return Date(timeIntervalSince1970: createdTime)
        } else if let dateString = string, let createdTime = Double(dateString), createdTime > 0 {
            return Date(timeIntervalSince1970: createdTime)
        }

        return nil
    }
}
