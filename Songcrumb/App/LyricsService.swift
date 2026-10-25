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
    private var blockedUntil = Date.distantPast
    private var lastRequest = Date.distantPast
    private let session: URLSession
    init(session: URLSession? = nil) {
        if let session { self.session = session; return }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        config.urlCache = nil
        self.session = URLSession(configuration: config, delegate: LyricsRedirectPolicy(), delegateQueue: nil)
    }
    enum Failure: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(s) = self { return s }; return nil }
    }
    func clear() { cache.removeAll(); misses.removeAll() }
    func fetch(_ track: Playback, preferences: Preferences) async throws -> LyricsDocument {
        guard preferences.provider != "local" else { throw Failure.message("Automatic internet lookup is off. Choose LRCLIB or your licensed provider in Lyrics settings.") }
        guard ["lrclib", "licensed"].contains(preferences.provider) else { throw Failure.message("Choose a supported lyrics provider.") }
        let clientIdentity = AppIdentity.projectURL.absoluteString
        let cacheKey = [preferences.provider, preferences.licensedEndpoint, clientIdentity, track.key].map { "\($0.utf8.count):\($0)" }.joined()
        if let cached = cache[cacheKey] { return cached }
        if let until = misses[cacheKey], until > Date() {
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
            misses[cacheKey] = Date().addingTimeInterval(600)
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
        guard blockedUntil <= Date() else {
            throw Failure.message("Provider asked us to wait. Retry after \(blockedUntil.formatted(date: .omitted, time: .shortened)).")
        }
        guard var url = URLComponents(string: base), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { throw Failure.message("The lyrics endpoint must be a valid HTTPS URL.") }
        let suppliedKeys = Set(query.map(\.name))
        url.queryItems = (url.queryItems ?? []).filter { !suppliedKeys.contains($0.name) } + query
        guard let endpoint = url.url else { throw Failure.message("Invalid lyrics provider URL.") }
        let delay = 0.4 - Date().timeIntervalSince(lastRequest)
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        try Task.checkCancellation()
        lastRequest = Date()
        var request = URLRequest(url: endpoint)
        request.setValue(AppIdentity.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.message("Invalid provider response.") }
        if http.statusCode == 429 || http.statusCode == 503 {
            let header = http.value(forHTTPHeaderField: "Retry-After") ?? "60"
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            let seconds = Double(header) ?? formatter.date(from: header)?.timeIntervalSinceNow ?? 60
            blockedUntil = Date().addingTimeInterval(max(1, seconds))
            throw Failure.message("Lyrics provider is busy. Retry later.")
        }
        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else { throw Failure.message("Lyrics provider returned HTTP \(http.statusCode).") }
        guard http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("json") == true else {
            throw Failure.message("Provider did not return JSON.")
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 512_000 else { throw Failure.message("Lyrics response exceeded the size limit.") }
            data.append(byte)
        }
        try Task.checkCancellation()
        return data
    }
}
