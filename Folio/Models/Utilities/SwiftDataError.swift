import Foundation

/// Error type used by SwiftData coordination utilities.
/// Currently minimal and tailored to existing call sites.
public enum SwiftDataError: Error, LocalizedError {
    /// A catch-all error with a descriptive message.
    case unknown(String)
    /// Optional convenience cases for clearer intent in future.
    case notFound(String)
    case saveFailed(String)

    // LocalizedError conformance for nicer error descriptions where surfaced.
    public var errorDescription: String? {
        switch self {
        case .unknown(let message):
            return message
        case .notFound(let message):
            return message
        case .saveFailed(let message):
            return message
        }
    }
}
