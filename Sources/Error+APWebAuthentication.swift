import Alamofire
import Foundation

public extension Error {
    var isConnectionError: Bool {
        if let currentError = self as? URLError {
            if currentError.code == URLError.timedOut ||
                currentError.code == URLError.dnsLookupFailed ||
                currentError.code == URLError.secureConnectionFailed ||
                currentError.code == URLError.notConnectedToInternet ||
                currentError.code == URLError.cannotFindHost ||
                currentError.code == URLError.networkConnectionLost
            {
                return true
            }
        }

        if let currentError = asAFError?.underlyingError as? URLError {
            if currentError.code == URLError.timedOut ||
                currentError.code == URLError.dnsLookupFailed ||
                currentError.code == URLError.secureConnectionFailed ||
                currentError.code == URLError.notConnectedToInternet ||
                currentError.code == URLError.cannotFindHost ||
                currentError.code == URLError.networkConnectionLost
            {
                return true
            }
        }

        return false
    }

    var isIgnorableError: Bool {
        isConnectionError || isCancelledError
    }

    var isCancelledError: Bool {
        // no point of showing badRequest or unkown error dialogs
        if let currentError = self as? APWebAuthenticationError, case APWebAuthenticationError.badRequest = currentError {
            return true
        }

        if let currentError = self as? APWebAuthenticationError, case APWebAuthenticationError.unknown = currentError {
            return true
        }

        if let currentError = self as? APWebAuthenticationError, case APWebAuthenticationError.canceled = currentError {
            return true
        }

        if let currentError = asAFError?.underlyingError as? APWebAuthenticationError, case APWebAuthenticationError.canceled = currentError {
            return true
        }

        if let currentError = self as? APWebAuthenticationError, case APWebAuthenticationError.loginCanceled = currentError {
            return true
        }

        if let currentError = asAFError?.underlyingError as? APWebAuthenticationError, case APWebAuthenticationError.loginCanceled = currentError {
            return true
        }

        if let currentError = self as? URLError, currentError.code == URLError.cancelled {
            return true
        }

        if let currentError = asAFError?.underlyingError as? URLError, currentError.code == URLError.cancelled {
            return true
        }

        if let currentError = self as? AFError, currentError.isExplicitlyCancelledError {
            return true
        }

        if let currentError = asAFError?.underlyingError as? URLError, currentError.localizedDescription == "cancelled" {
            return true
        }

        if localizedDescription == "cancelled" {
            return true
        }

        return false
    }
}
