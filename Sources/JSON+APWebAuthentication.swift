import Foundation
@preconcurrency import SwiftyJSON

// MARK: - JSON Extensions

/// Extensions to `JSON` for safe type conversion and Instagram API compatibility.
///
/// These extensions provide robust type conversion methods that handle Instagram's
/// inconsistent API responses where values may be:
/// - Strings that should be numbers
/// - Numbers that should be strings
/// - Timestamps in various formats
/// - IDs as either strings or integers
public extension JSON {
    
    /// Safely returns a string representation of an ID from various formats.
    ///
    /// Instagram's API inconsistently returns IDs as either strings or integers.
    /// This property handles both cases and always returns a string representation.
    ///
    /// **Conversion Priority:**
    /// 1. String value (if present and non-empty)
    /// 2. Int64 value (for large IDs)
    /// 3. Int value (fallback)
    /// 4. Returns `nil` if value is 0 or missing
    ///
    /// **Example:**
    /// ```swift
    /// // String ID
    /// let json1 = JSON(["id": "1234567890"])
    /// print(json1["id"].idString) // "1234567890"
    ///
    /// // Integer ID
    /// let json2 = JSON(["id": 1234567890])
    /// print(json2["id"].idString) // "1234567890"
    ///
    /// // Large integer ID (Int64)
    /// let json3 = JSON(["id": 1234567890123456789])
    /// print(json3["id"].idString) // "1234567890123456789"
    ///
    /// // Missing or zero
    /// let json4 = JSON(["id": 0])
    /// print(json4["id"].idString) // nil
    /// ```
    ///
    /// - Returns: String representation of the ID, or `nil` if invalid
    var idString: String? {
        // Priority 1: String value (if present and not empty)
        if let stringID = self.string, !stringID.isEmpty {
            return stringID
        }

        // Priority 2: Integer value (Int64 for large IDs, then Int)
        let intID: Int64 = self.int64 ?? Int64(self.int ?? 0)

        // Check if non-zero
        if intID != 0 {
            return String(intID)
        }

        // All conversions failed or value is zero
        return nil
    }

    /// Safely converts the JSON value to an Int32.
    ///
    /// Attempts multiple conversion strategies to handle Instagram's API
    /// inconsistencies where numbers may be provided as strings.
    ///
    /// **Conversion Priority:**
    /// 1. Direct Int32 value
    /// 2. Int value converted to Int32
    /// 3. String value parsed and converted to Int32
    ///
    /// **Example:**
    /// ```swift
    /// // Direct Int32
    /// let json1 = JSON(["count": 100])
    /// print(json1["count"].int32Number) // 100
    ///
    /// // String number
    /// let json2 = JSON(["count": "200"])
    /// print(json2["count"].int32Number) // 200
    ///
    /// // Invalid string
    /// let json3 = JSON(["count": "abc"])
    /// print(json3["count"].int32Number) // nil
    /// ```
    ///
    /// - Returns: Int32 value, or `nil` if conversion fails
    var int32Number: Int32? {
        // Priority 1: Direct Int32 value
        if let value = self.int32 {
            return value
        }
        
        // Priority 2: Int value or string parsed as Int
        if let intValue = self.int ?? self.string.flatMap(Int.init) {
            return Int32(intValue)
        }
        
        return nil
    }

    /// Safely converts the JSON value to a Date from Unix timestamp.
    ///
    /// Instagram's API provides timestamps as either Double or String values
    /// representing seconds since Unix epoch (January 1, 1970).
    ///
    /// **Conversion Priority:**
    /// 1. Direct Double value
    /// 2. String value parsed as Double
    /// 3. Validates timestamp is positive
    ///
    /// **Example:**
    /// ```swift
    /// // Double timestamp
    /// let json1 = JSON(["created_at": 1609459200.0])
    /// print(json1["created_at"].date)
    /// // 2021-01-01 00:00:00 +0000
    ///
    /// // String timestamp
    /// let json2 = JSON(["created_at": "1609459200"])
    /// print(json2["created_at"].date)
    /// // 2021-01-01 00:00:00 +0000
    ///
    /// // Invalid timestamp
    /// let json3 = JSON(["created_at": -1])
    /// print(json3["created_at"].date) // nil
    ///
    /// // Missing timestamp
    /// let json4 = JSON(["created_at": NSNull()])
    /// print(json4["created_at"].date) // nil
    /// ```
    ///
    /// - Returns: Date object, or `nil` if conversion fails or timestamp is invalid
    var date: Date? {
        // Get timestamp as Double (direct or from string)
        let timestamp = self.double ?? self.string.flatMap(Double.init)

        // Validate timestamp is positive
        guard let finalTimestamp = timestamp, finalTimestamp > 0 else {
            return nil
        }
        
        return Date(timeIntervalSince1970: finalTimestamp)
    }
}

