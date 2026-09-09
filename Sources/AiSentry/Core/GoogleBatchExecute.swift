import Foundation

/// Google's internal "batchexecute" RPC protocol, used by Gemini/AI Studio's web
/// frontends instead of a public REST API. Undocumented and shape-shifts with every
/// deploy, but the pieces needed to call it (anti-CSRF token, session id, build label)
/// are all embedded in the page's own HTML, so they can be read fresh on every call
/// instead of hardcoded — that's what keeps this from breaking the moment Google ships
/// a new build label.
enum GoogleBatchExecute {
    struct Tokens {
        let at: String
        let sid: String
        let buildLabel: String
    }

    /// Pulls `SNlM0e` (anti-CSRF token), `FdrFJe` (session id) and `cfb2h` (build
    /// label) out of the inline `WIZ_global_data = {...}` blob in the page HTML.
    static func extractTokens(from html: String) -> Tokens? {
        guard
            let at = field("SNlM0e", in: html),
            let sid = field("FdrFJe", in: html),
            let buildLabel = field("cfb2h", in: html)
        else { return nil }
        return Tokens(at: at, sid: sid, buildLabel: buildLabel)
    }

    private static func field(_ key: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\"\(key)\":\"([^\"]*)\"") else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let valueRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[valueRange])
    }

    static func requestURL(host: String, rpcId: String, sourcePath: String, tokens: Tokens) -> URL? {
        var components = URLComponents(string: "https://\(host)/_/BardChatUi/data/batchexecute")
        components?.queryItems = [
            URLQueryItem(name: "rpcids", value: rpcId),
            URLQueryItem(name: "source-path", value: sourcePath),
            URLQueryItem(name: "bl", value: tokens.buildLabel),
            URLQueryItem(name: "f.sid", value: tokens.sid),
            URLQueryItem(name: "hl", value: "en"),
            URLQueryItem(name: "_reqid", value: String(Int.random(in: 100_000...999_999))),
            URLQueryItem(name: "rt", value: "c"),
        ]
        return components?.url
    }

    static func requestBody(rpcId: String, args: String, tokens: Tokens) -> String {
        let payload = "[[[\"\(rpcId)\",\(argsJSON: args),null,\"generic\"]]]"
        let encodedPayload = payload.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? payload
        let encodedAt = tokens.at.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? tokens.at
        return "f.req=\(encodedPayload)&at=\(encodedAt)&"
    }

    /// Decodes the `)]}'`-prefixed, length-chunked response format and returns the
    /// decoded payload (already un-nested from its `wrb.fr` envelope) for `rpcId`.
    static func firstPayload(forRpcId rpcId: String, in responseText: String) -> Any? {
        let lines = responseText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var i = 0
        while i < lines.count, Int(lines[i].trimmingCharacters(in: .whitespaces)) == nil {
            i += 1
        }
        while i + 1 < lines.count {
            guard Int(lines[i].trimmingCharacters(in: .whitespaces)) != nil else { i += 1; continue }
            let jsonLine = lines[i + 1]
            i += 2
            guard
                let data = jsonLine.data(using: .utf8),
                let outer = try? JSONSerialization.jsonObject(with: data) as? [[Any]]
            else { continue }
            for entry in outer {
                guard
                    entry.count > 2,
                    (entry[0] as? String) == "wrb.fr",
                    (entry[1] as? String) == rpcId,
                    let payloadString = entry[2] as? String,
                    let payloadData = payloadString.data(using: .utf8)
                else { continue }
                return try? JSONSerialization.jsonObject(with: payloadData)
            }
        }
        return nil
    }
}

private extension String.StringInterpolation {
    /// Embeds `args` (already a JSON-encoded string like `"[]"`) as a JSON *string*
    /// literal inside the surrounding f.req array, matching what the real client sends.
    mutating func appendInterpolation(argsJSON args: String) {
        if let data = try? JSONSerialization.data(withJSONObject: [args]),
           let encoded = String(data: data, encoding: .utf8) {
            appendLiteral(String(encoded.dropFirst().dropLast()))
        } else {
            appendLiteral("\"\(args)\"")
        }
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
