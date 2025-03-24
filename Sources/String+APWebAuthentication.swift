import Foundation

extension String {
    public static var documentDirectory: String {
        NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    }

    public var javascriptEscaped: String {
        replacingOccurrences(of: "\"", with: "\\\"")
    }

    public var urlEscaped: String {
        if let escapedString = addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")) {
            return escapedString
        }

        return self
    }

    public var urlUnescaped: String {
        if let unescapedString = removingPercentEncoding {
            return unescapedString
        }

        return self
    }

    public var parameters: [String: String] {
        var queryParams = [String: String]()

        // If we are here it's was native iOS authorization and we have redirect URL like this:
        // testapp123://foursquare?access_token=ACCESS_TOKEN
        let parameters = components(separatedBy: "&")
        for string in parameters {
            let keyValue = string.components(separatedBy: "=")
            if keyValue.count == 2 {
                queryParams[keyValue[0]] = keyValue[1].urlUnescaped
            }
        }

        return queryParams
    }
}
