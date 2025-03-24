import Foundation

extension URL {
    /// [RFC-5849 Section 3.4.1.2](https://tools.ietf.org/html/rfc5849#section-3.4.1.2)
    var oAuthBaseURL: String {
        let scheme = self.scheme?.lowercased() ?? ""
        let host = self.host?.lowercased() ?? ""

        var authority = ""
        if let user = self.user, let pw = password {
            authority = user + ":" + pw + "@"
        } else if let user = self.user {
            authority = user + "@"
        }

        var port = ""
        if let iport = self.port, iport != 80, scheme == "http" {
            port = ":\(iport)"
        } else if let iport = self.port, iport != 443, scheme == "https" {
            port = ":\(iport)"
        }

        return scheme + "://" + authority + host + port + path
    }

    public var withoutScheme: URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = nil

        guard let url = components?.url else { return nil }

        let urlString = url.absoluteString
        let index = urlString.index(urlString.startIndex, offsetBy: 2)
        let modifiedString = String(describing: urlString[index...])

        return URL(string: modifiedString)
    }

    public func conformToHypertextProtocol() -> Bool {
        guard let scheme = self.scheme, scheme == URLComponents.Schemes.http || scheme == URLComponents.Schemes.https else {
            return false
        }

        return true
    }

    public var parameters: [String: String] {
        var queryParams = [String: String]()

        // If we are here it's was native iOS authorization and we have redirect URL like this:
        // testapp123://foursquare?access_token=ACCESS_TOKEN
        if let parameters = query?.components(separatedBy: "&") {
            for string in parameters {
                let keyValue = string.components(separatedBy: "=")
                if keyValue.count == 2 {
                    queryParams[keyValue[0]] = keyValue[1].urlUnescaped
                }
            }
        }

        // If we are here it's was web authorization and we have redirect URL like this:
        // testapp123://foursquare#access_token=ACCESS_TOKEN
        if let parameters = fragment?.components(separatedBy: "&") {
            for string in parameters {
                let keyValue = string.components(separatedBy: "=")
                if keyValue.count == 2 {
                    queryParams[keyValue[0]] = keyValue[1].urlUnescaped
                }
            }
        }

        return queryParams
    }

    public func getResponse() -> Result<[String: String], APWebAuthenticationError> {
        let params = parameters

        if let errorMessage = params["error"]?.removingPercentEncoding {
            return (.failure(APWebAuthenticationError.failed(reason: errorMessage)))
        } else if let errorMessage = params["error_description"]?.removingPercentEncoding {
            return (.failure(APWebAuthenticationError.failed(reason: errorMessage)))
        } else if let errorMessage = params["error_message"]?.removingPercentEncoding {
            if params["error_type"] == "login_failed" {
                return (.failure(APWebAuthenticationError.loginFailed(reason: errorMessage)))
            }

            return (.failure(APWebAuthenticationError.failed(reason: errorMessage)))
        }

        return .success(params)
    }
}

extension URLComponents {
    struct Schemes {
        static let http = "http"
        static let https = "https"
    }
}
