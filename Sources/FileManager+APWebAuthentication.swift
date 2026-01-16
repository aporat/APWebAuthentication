import Foundation

// MARK: - FileManager Extensions

/// Extensions to `FileManager` for common directory access.
///
/// These extensions provide convenient access to standard iOS directories
/// used for storing authentication data, settings, and other app data.
public extension FileManager {
    
    /// The URL to the app's documents directory.
    ///
    /// The documents directory is the primary location for user-generated content
    /// and application data that should be backed up by iTunes/iCloud.
    ///
    /// **Use Cases:**
    /// - Storing authentication settings
    /// - Saving user preferences
    /// - Caching session cookies
    /// - Storing downloaded content
    ///
    /// **Example:**
    /// ```swift
    /// if let documentsURL = FileManager.documentsDirectoryURL {
    ///     let settingsFile = documentsURL.appendingPathComponent("settings.plist")
    ///     try data.write(to: settingsFile)
    /// }
    /// ```
    ///
    /// **File Backup:**
    /// Files in the documents directory are automatically backed up by iOS
    /// unless explicitly excluded using file attributes.
    ///
    /// - Returns: URL to the documents directory, or `nil` if it cannot be determined
    static var documentsDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    /// The URL to the app's caches directory.
    ///
    /// The caches directory is for temporary data that can be regenerated
    /// if needed. iOS may delete files from this directory when storage is low.
    ///
    /// **Use Cases:**
    /// - Caching API responses
    /// - Temporary file downloads
    /// - Image caches
    /// - Any regenerable data
    ///
    /// **Example:**
    /// ```swift
    /// if let cachesURL = FileManager.cachesDirectoryURL {
    ///     let cacheFile = cachesURL.appendingPathComponent("temp.dat")
    ///     try data.write(to: cacheFile)
    /// }
    /// ```
    ///
    /// **Important:** Files in the caches directory are NOT backed up
    /// and may be deleted by the system at any time.
    ///
    /// - Returns: URL to the caches directory, or `nil` if it cannot be determined
    static var cachesDirectoryURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
    
    /// The URL to the app's temporary directory.
    ///
    /// The temporary directory is for short-lived files that should be deleted
    /// when no longer needed. iOS automatically cleans up old temporary files.
    ///
    /// **Use Cases:**
    /// - Processing temporary files
    /// - Unzipping archives
    /// - Intermediate file operations
    /// - Scratch space
    ///
    /// **Example:**
    /// ```swift
    /// let tempURL = FileManager.temporaryDirectoryURL
    /// let tempFile = tempURL.appendingPathComponent(UUID().uuidString)
    /// try data.write(to: tempFile)
    /// // Don't forget to clean up!
    /// try FileManager.default.removeItem(at: tempFile)
    /// ```
    ///
    /// **Important:** Always clean up temporary files when done.
    /// The system may not delete them immediately.
    ///
    /// - Returns: URL to the temporary directory
    static var temporaryDirectoryURL: URL {
        FileManager.default.temporaryDirectory
    }
}

// MARK: - File Operations

public extension FileManager {
    
    /// Checks if a file exists at the specified URL.
    ///
    /// **Example:**
    /// ```swift
    /// if FileManager.default.fileExists(at: fileURL) {
    ///     print("File exists")
    /// }
    /// ```
    ///
    /// - Parameter url: The file URL to check
    /// - Returns: `true` if the file exists, `false` otherwise
    func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path)
    }
    
    /// Safely removes a file if it exists.
    ///
    /// Unlike `removeItem(at:)`, this method doesn't throw an error
    /// if the file doesn't exist.
    ///
    /// **Example:**
    /// ```swift
    /// try? FileManager.default.removeItemIfExists(at: fileURL)
    /// // File is gone, or wasn't there to begin with
    /// ```
    ///
    /// - Parameter url: The file URL to remove
    /// - Throws: File system errors (but not "file doesn't exist" errors)
    func removeItemIfExists(at url: URL) throws {
        guard fileExists(at: url) else { return }
        try removeItem(at: url)
    }
    
    /// Creates a directory at the specified URL if it doesn't exist.
    ///
    /// **Example:**
    /// ```swift
    /// let customDir = documentsURL.appendingPathComponent("MyData")
    /// try FileManager.default.createDirectoryIfNeeded(at: customDir)
    /// // Directory now exists
    /// ```
    ///
    /// - Parameters:
    ///   - url: The directory URL to create
    ///   - createIntermediates: Whether to create intermediate directories (default: true)
    /// - Throws: File system errors
    func createDirectoryIfNeeded(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool = true
    ) throws {
        guard !fileExists(at: url) else { return }
        try createDirectory(at: url, withIntermediateDirectories: createIntermediates)
    }
}
