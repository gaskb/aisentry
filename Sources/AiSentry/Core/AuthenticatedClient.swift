import Foundation

/// Thin helper around URLSession for the small JSON GET/POST calls each provider needs.
enum AuthenticatedClient {
    static func getJSON(
        url: URL,
        cookie: String? = nil,
        bearerToken: String? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> Any {
        var request = URLRequest(url: url)
        apply(cookie: cookie, bearerToken: bearerToken, extraHeaders: extraHeaders, to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONSerialization.jsonObject(with: data)
    }

    static func postJSON(
        url: URL,
        body: [String: Any] = [:],
        cookie: String? = nil,
        bearerToken: String? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> Any {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        apply(cookie: cookie, bearerToken: bearerToken, extraHeaders: extraHeaders, to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func apply(
        cookie: String?,
        bearerToken: String?,
        extraHeaders: [String: String],
        to request: inout URLRequest
    ) {
        if let cookie, !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        if let bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            request.setValue(bearerToken, forHTTPHeaderField: "x-api-key")
        }
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw UsageSourceError.http(http.statusCode)
        }
    }
}

/// Minimal helpers for pulling values out of the `Any` JSON blobs returned above,
/// without pulling in a full Codable model per (unofficial, shape-shifting) endpoint.
extension Dictionary where Key == String, Value == Any {
    func number(at path: String...) -> Double? {
        var current: Any? = self
        for key in path {
            current = (current as? [String: Any])?[key]
        }
        if let value = current as? NSNumber { return value.doubleValue }
        return nil
    }

    func string(at path: String...) -> String? {
        var current: Any? = self
        for key in path {
            current = (current as? [String: Any])?[key]
        }
        return current as? String
    }

    func dict(at path: String...) -> [String: Any]? {
        var current: Any? = self
        for key in path {
            current = (current as? [String: Any])?[key]
        }
        return current as? [String: Any]
    }
}
