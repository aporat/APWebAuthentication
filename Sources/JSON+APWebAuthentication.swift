import Foundation
import SwiftyJSON

public extension JSON {
    /// Safely returns a string representation of an ID that might be stored as a string or an integer.
    var idString: String? {
        // First, prioritize the string value if it's present and not empty.
        if let stringID = self.string, !stringID.isEmpty {
            return stringID
        }

        // Next, get an integer value, falling back from Int64 to Int, and finally to 0.
        let intID: Int64 = self.int64 ?? Int64(self.int ?? 0)

        // Now that we have a definite value, check if it's non-zero.
        if intID != 0 {
            return String(intID)
        }

        // If all checks fail, return nil.
        return nil
    }

    /// Safely converts the JSON value to an Int32, trying Int32, Int, and String representations.
    var int32Number: Int32? {
        // Prioritize the direct Int32 value.
        if let value = self.int32 {
            return value
        }
        // Use flatMap to safely unwrap the optional string and then attempt to initialize an Int.
        if let intValue = self.int ?? self.string.flatMap(Int.init) {
            return Int32(intValue)
        }
        return nil
    }

    /// Safely converts the JSON value to a Date, assuming it's a Unix timestamp
    /// represented as either a Double or a String.
    var date: Date? {
        // Use nil-coalescing to get the Double value, either directly
        // or by converting the string.
        let timestamp = self.double ?? self.string.flatMap(Double.init)

        // Safely unwrap the final timestamp and check if it's positive.
        guard let finalTimestamp = timestamp, finalTimestamp > 0 else {
            return nil
        }
        
        return Date(timeIntervalSince1970: finalTimestamp)
    }
}

