import Foundation

enum NoiseFormatters {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static let filenameDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let iso8601 = ISO8601DateFormatter()

    static func clock(_ seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        let minutes = safeSeconds / 60
        let seconds = safeSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func minutes(_ seconds: Int) -> Int {
        Int((Double(max(0, seconds)) / 60.0).rounded())
    }
}
