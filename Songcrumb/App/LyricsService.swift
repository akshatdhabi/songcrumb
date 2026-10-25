import Foundation

final class LyricsRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let original = task.originalRequest?.url, let destination = request.url,
              ProviderPolicy.sameHTTPSOrigin(original, destination) else { completionHandler(nil); return }
        completionHandler(request)
    }
}

actor LyricsService {
    private var cache: [String: LyricsDocument] = [:]
    private var misses: [String: Date] = [:]
    private struct Backoff { let until: Date; let attempt: Int; let status: Int? }
    private var backoffs: [String: Backoff] = [:]
    private let clock: @Sendable () -> Date
    private let jitter: @Sendable () -> Double
    private var lastRequest = Date.distantPast
    private let session: URLSession
    init(session: URLSession? = nil, clock: @escaping @Sendable () -> Date = { Date() },
         jitter: @escaping @Sendable () -> Double = { Double.random(in: 0...0.2) }) {
        self.clock = clock; self.jitter = jitter
        if let session { self.session = session; return }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        config.urlCache = nil
        self.session = URLSession(configuration: config, delegate: LyricsRedirectPolicy(), delegateQueue: nil)
    }
    enum Failure: LocalizedError {
        case message(String)
        case temporary(until: Date, status: Int?)
        var retryDate: Date? { if case let .temporary(until, _) = self { return until }; return nil }
        var errorDescription: String? {
            switch self {
            case .message(let value): return value
            case .temporary(let until, let status):
                let reason = status == 429 ? "Lyrics service asked for a short pause." : "Lyrics are taking a moment."
                return "\(reason) Trying again at \(until.formatted(date: .omitted, time: .standard))."
            }
        }
    }
    func clear() { cache.removeAll(); misses.removeAll() }
    private func key(_ track: Playback, preferences: Preferences) -> String {
        [preferences.provider, preferences.licensedEndpoint, AppIdentity.projectURL.absoluteString, track.key]
            .map { "\($0.utf8.count):\($0)" }.joined()
    }
    func invalidate(_ track: Playback, preferences: Preferences) {
        let value = key(track, preferences: preferences)
        cache[value] = nil; misses[value] = nil
        // A refresh never overrides server backoff or erases other songs' lyrics.
    }
    func fetch(_ track: Playback, preferences: Preferences) async throws -> LyricsDocument {
        guard preferences.provider != "local" else { throw Failure.message("Automatic internet lookup is off. Choose LRCLIB or your licensed provider in Lyrics settings.") }
        guard ["lrclib", "licensed"].contains(preferences.provider) else { throw Failure.message("Choose a supported lyrics provider.") }
        let cacheKey = key(track, preferences: preferences)
        if let cached = cache[cacheKey] { return cached }
        if let until = misses[cacheKey], until > clock() {
            throw Failure.message("No confident online match was found recently. Reload to try again.")
        }
        guard (1...3600).contains(track.duration), !track.artist.isEmpty else {
            throw Failure.message("The player has not supplied enough metadata for a safe lyrics match yet.")
        }
        let community = preferences.provider == "lrclib"
        let base = community ? "https://lrclib.net/api/get" : preferences.licensedEndpoint
        let title = community ? RecordingMatcher.cleanTitle(track.title) : track.title
        let query = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))
        ]
        var candidates: [LyricsRecord] = []
        if let data = try await request(base, query: query) {
            let record = try JSONDecoder().decode(LyricsRecord.self, from: data)
            if record.matches(track) { candidates.append(record) }
        }
        // An album / presentation-label difference must not make a good recording invisible.
        // Search is bounded to one fallback, never a scrape or a fuzzy first-result guess.
        if community, candidates.first.map({ !$0.hasUsableSyncedLyrics && $0.instrumental != true }) ?? true {
            let searchQuery = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: track.artist)]
            do {
                if let data = try await request("https://lrclib.net/api/search", query: searchQuery) {
                    let results = try JSONDecoder().decode([LyricsRecord].self, from: data)
                    candidates.append(contentsOf: results.prefix(200))
                }
            } catch {
                try Task.checkCancellation()
                // A failed optional search must not erase a usable exact plain-text match.
                if !candidates.contains(where: \.isUsable) { throw error }
            }
        }
        let valid = candidates.filter { $0.matches(track) && $0.isUsable }
        let synced = valid.filter(\.hasUsableSyncedLyrics)
        guard let record = RecordingMatcher.best(in: synced.isEmpty ? valid : synced, for: track) else {
            if misses.count >= 100 { misses.removeAll() }
            misses[cacheKey] = clock().addingTimeInterval(600)
            throw Failure.message("No confident online lyrics match for this recording. Songcrumb will try automatically when the song changes; use Reload to check again.")
        }
        if !community {
            guard record.licenseConfirmed == true, let credit = record.attribution, !credit.isEmpty else {
                throw Failure.message("Licensed provider must confirm display rights and supply attribution.")
            }
        }
        let doc = record.document(attribution: "LRCLIB · matched recording · community supplied")
        guard doc.synced || !doc.plain.isEmpty || doc.instrumental else {
            throw Failure.message("The matched recording has no lyrics available online.")
        }
        if cache.count >= 30 { cache.removeAll() }
        if community || record.allowSessionCache == true { cache[cacheKey] = doc }
        return doc
    }
    private func request(_ base: String, query: [URLQueryItem]) async throws -> Data? {
        guard var url = URLComponents(string: base), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { throw Failure.message("The lyrics endpoint must be a valid HTTPS URL.") }
        let suppliedKeys = Set(query.map(\.name))
        url.queryItems = (url.queryItems ?? []).filter { !suppliedKeys.contains($0.name) } + query
        guard let endpoint = url.url else { throw Failure.message("Invalid lyrics provider URL.") }
        let origin = "\(endpoint.scheme ?? "")://\(endpoint.host?.lowercased() ?? ""):\(endpoint.port ?? 443)"
        if let backoff = backoffs[origin], backoff.until > clock() {
            throw Failure.temporary(until: backoff.until, status: backoff.status)
        }
        let delay = 0.4 - Date().timeIntervalSince(lastRequest)
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        try Task.checkCancellation()
        lastRequest = Date()
        var request = URLRequest(url: endpoint)
        request.setValue(AppIdentity.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do { (bytes, response) = try await session.bytes(for: request) }
        catch {
            try Task.checkCancellation()
            if let error = error as? URLError,
               [.timedOut, .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed].contains(error.code) {
                throw temporaryFailure(origin: origin, status: nil, header: nil)
            }
            throw error
        }
        guard let http = response as? HTTPURLResponse else { throw Failure.message("Invalid provider response.") }
        if [429, 500, 502, 503, 504].contains(http.statusCode) {
            throw temporaryFailure(origin: origin, status: http.statusCode, header: http.value(forHTTPHeaderField: "Retry-After"))
        }
        if http.statusCode == 404 { backoffs[origin] = nil; return nil }
        guard http.statusCode == 200 else { throw Failure.message("Lyrics provider returned HTTP \(http.statusCode).") }
        guard http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("json") == true else {
            throw Failure.message("Provider did not return JSON.")
        }
        var data = Data()
        do {
            for try await byte in bytes {
                guard data.count < 512_000 else { throw Failure.message("Lyrics response exceeded the size limit.") }
                data.append(byte)
            }
        } catch {
            try Task.checkCancellation()
            if let error = error as? URLError,
               [.timedOut, .networkConnectionLost, .notConnectedToInternet].contains(error.code) {
                throw temporaryFailure(origin: origin, status: nil, header: nil)
            }
            throw error
        }
        try Task.checkCancellation()
        backoffs[origin] = nil
        return data
    }
    private func temporaryFailure(origin: String, status: Int?, header: String?) -> Failure {
        let attempt = (backoffs[origin]?.attempt ?? 0) + 1
        let delay = LyricsRetryPolicy.delay(header: header, status: status, attempt: attempt, now: clock(), jitter: jitter())
        let until = clock().addingTimeInterval(delay)
        backoffs[origin] = Backoff(until: until, attempt: attempt, status: status)
        return .temporary(until: until, status: status)
    }
}
