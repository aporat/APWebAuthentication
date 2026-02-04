import Foundation

// MARK: - Data Extensions

/// Extensions to `Data` for common byte array operations.
///
/// These extensions provide convenient ways to work with `Data` objects
/// when byte-level access is needed, such as:
/// - Cryptographic operations
/// - Binary protocol parsing
/// - Low-level data manipulation
/// - Hashing and checksums
extension Data {

    /// Returns all bytes in the data as an array of `UInt8`.
    ///
    /// This property provides convenient access to the raw bytes of the `Data` object,
    /// which is useful for:
    /// - Passing to cryptographic functions
    /// - Bitwise operations
    /// - Binary protocol implementations
    /// - Debugging and inspection
    ///
    /// **Example:**
    /// ```swift
    /// let data = "Hello".data(using: .utf8)!
    /// let bytes = data.allBytes
    /// print(bytes) // [72, 101, 108, 108, 111]
    ///
    /// // Use in cryptographic operations
    /// import CryptoKit
    /// let hash = SHA256.hash(data: Data(bytes))
    /// ```
    ///
    /// **Performance:**
    /// This creates a copy of the data as an array. For large data objects,
    /// consider using `withUnsafeBytes` if you only need temporary access.
    ///
    /// - Returns: An array containing all bytes in the data
    var allBytes: [UInt8] {
        [UInt8](self)
    }
}
