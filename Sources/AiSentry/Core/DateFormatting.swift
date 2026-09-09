import Foundation

enum ResetFormatting {
    nonisolated(unsafe) private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let isoParserNoFraction: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    /// Turns an ISO-8601 "resets_at" timestamp into "si resetta tra 3h 20m" style text.
    static func resetsIn(_ isoString: String?) -> String? {
        guard let isoString else { return nil }
        let date = isoParser.date(from: isoString) ?? isoParserNoFraction.date(from: isoString)
        guard let date else { return nil }

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "si resetta a breve" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 24 {
            let days = hours / 24
            return "si resetta tra \(days)g"
        } else if hours > 0 {
            return "si resetta tra \(hours)h \(minutes)m"
        } else {
            return "si resetta tra \(minutes)m"
        }
    }
}
