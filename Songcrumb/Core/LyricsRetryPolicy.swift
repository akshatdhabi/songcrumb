import Foundation

/// Retry-After is a lower bound, including HTTP-date values. A small positive
/// jitter avoids synchronized retries without shortening the provider's wait.
enum LyricsRetryPolicy {
    static func delay(header: String?, status: Int?, attempt: Int, now: Date, jitter: Double) -> TimeInterval {
        let fallback = min(120, (status == 429 ? 30.0 : 2.0) * pow(2, Double(min(6, max(0, attempt - 1)))))
        var requested: TimeInterval?
        if let value = header?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }), let seconds = UInt32(value) { requested = Double(seconds) }
            else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                requested = formatter.date(from: value).map { max(0, $0.timeIntervalSince(now)) }
            }
        }
        let base = max(1, max(requested ?? 0, fallback))
        let factor = jitter.isFinite ? min(0.3, max(0, jitter)) : 0
        return base * (1 + factor)
    }
}
