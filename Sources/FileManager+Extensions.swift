import Foundation

public extension FileManager {
    /// Safely returns the URL for the user's document directory.
    static var documentsDirectoryURL: URL? {
        // This is the most robust way to get the documents directory.
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}
