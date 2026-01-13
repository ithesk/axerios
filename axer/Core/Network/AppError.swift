import Foundation
import RollbarNotifier

// MARK: - Crash Reporter

/// Wrapper for Rollbar error reporting
enum CrashReporter {
    /// Log an error to Rollbar
    static func log(_ error: Error, context: [String: Any]? = nil) {
        let appError = AppError.from(error)

        var data: [String: Any] = [
            "error_type": String(describing: appError),
            "original_error": error.localizedDescription,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let context = context {
            data.merge(context) { _, new in new }
        }

        Rollbar.errorMessage(appError.errorDescription ?? "Unknown error", data: data)
    }

    /// Log an AppError directly
    static func log(_ appError: AppError, context: [String: Any]? = nil) {
        var data: [String: Any] = [
            "error_type": String(describing: appError),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let context = context {
            data.merge(context) { _, new in new }
        }

        Rollbar.errorMessage(appError.errorDescription ?? "Unknown error", data: data)
    }

    /// Log info message
    static func info(_ message: String) {
        Rollbar.infoMessage(message)
    }
}

// MARK: - App Error

/// Centralized error handling for the app
enum AppError: LocalizedError, Equatable {
    case networkError
    case serverError(code: Int)
    case unauthorized
    case notFound
    case invalidData
    case timeout
    case unknown(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .networkError:
            return L10n.Error.network
        case .serverError(let code):
            return L10n.Error.serverWithCode(code)
        case .unauthorized:
            return L10n.Error.unauthorized
        case .notFound:
            return L10n.Error.notFound
        case .invalidData:
            return L10n.Error.invalidData
        case .timeout:
            return L10n.Error.timeout
        case .unknown(let message):
            return message.isEmpty ? L10n.Error.unknown : message
        }
    }

    // MARK: - Recovery Suggestion

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return L10n.Error.networkSuggestion
        case .serverError:
            return L10n.Error.serverSuggestion
        case .unauthorized:
            return L10n.Error.unauthorizedSuggestion
        case .timeout:
            return L10n.Error.timeoutSuggestion
        default:
            return L10n.Error.retrySuggestion
        }
    }

    // MARK: - Retryable

    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .timeout:
            return true
        case .unauthorized, .notFound, .invalidData, .unknown:
            return false
        }
    }

    // MARK: - Equatable

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError, .networkError),
             (.unauthorized, .unauthorized),
             (.notFound, .notFound),
             (.invalidData, .invalidData),
             (.timeout, .timeout):
            return true
        case (.serverError(let lCode), .serverError(let rCode)):
            return lCode == rCode
        case (.unknown(let lMsg), .unknown(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }

    // MARK: - Factory Methods

    /// Creates an AppError from a generic Error
    static func from(_ error: Error) -> AppError {
        // Check if already an AppError
        if let appError = error as? AppError {
            return appError
        }

        // Check for URL errors (network issues)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError
            case .timedOut:
                return .timeout
            default:
                return .networkError
            }
        }

        // Check error description for common patterns
        let description = error.localizedDescription.lowercased()

        if description.contains("network") || description.contains("internet") || description.contains("connection") {
            return .networkError
        }

        if description.contains("unauthorized") || description.contains("401") {
            return .unauthorized
        }

        if description.contains("not found") || description.contains("404") {
            return .notFound
        }

        if description.contains("timeout") {
            return .timeout
        }

        // Default to unknown with the original message
        return .unknown(error.localizedDescription)
    }
}

// MARK: - Error State

/// Represents the error state for views
struct ErrorState: Equatable {
    let error: AppError
    let timestamp: Date

    init(error: AppError, logToRollbar: Bool = true) {
        self.error = error
        self.timestamp = Date()

        if logToRollbar {
            CrashReporter.log(error)
        }
    }

    init(from error: Error, logToRollbar: Bool = true) {
        self.error = AppError.from(error)
        self.timestamp = Date()

        if logToRollbar {
            CrashReporter.log(error)
        }
    }

    var message: String {
        error.errorDescription ?? L10n.Error.unknown
    }

    var suggestion: String? {
        error.recoverySuggestion
    }

    var canRetry: Bool {
        error.isRetryable
    }
}
