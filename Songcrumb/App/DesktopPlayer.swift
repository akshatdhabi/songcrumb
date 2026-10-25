import Foundation

/// Direct public Apple Events; deliberately avoids the main-thread-only NSAppleScript engine.
/// Descriptor creation, event sends and the metadata cache are confined to this serial queue.
final class DesktopPlayer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "io.github.akshatdhabi.songcrumb.automation", qos: .utility)
    private var dictionaries: [URL: ScriptingDictionary] = [:]
    private var metadata: [MusicSource: CachedTrack] = [:]
    struct Failure: Error, Sendable { let code: Int; let message: String }
    private struct CachedTrack {
        let processID: Int32
        let track: Playback
        let date: Date
    }

    func read(_ source: MusicSource, processID: Int32, applicationURL: URL) async -> Result<Playback?, Failure> {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                autoreleasepool {
                    do { continuation.resume(returning: .success(try execute(source, processID: processID, applicationURL: applicationURL))) }
                    catch let failure as Failure { continuation.resume(returning: .failure(failure)) }
                    catch { continuation.resume(returning: .failure(Failure(code: (error as NSError).code, message: error.localizedDescription))) }
                }
            }
        }
    }

    private func execute(_ source: MusicSource, processID: Int32, applicationURL: URL) throws -> Playback? {
        let dictionary: ScriptingDictionary
        if let cached = dictionaries[applicationURL] { dictionary = cached }
        else { dictionary = try ScriptingDictionary(applicationURL: applicationURL); dictionaries[applicationURL] = dictionary }
        let target = NSAppleEventDescriptor(processIdentifier: processID)
        let deadline = ProcessInfo.processInfo.systemUptime + 4
        func readProperty(_ name: String, container: NSAppleEventDescriptor? = nil) throws -> NSAppleEventDescriptor {
            guard let property = dictionary.properties[name.lowercased()] else {
                throw Failure(code: -1708, message: "The installed app does not expose \(name).")
            }
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw Failure(code: -1712, message: "Playback request timed out.") }
            let event = NSAppleEventDescriptor.appleEvent(withEventClass: Self.code("core"), eventID: Self.code("getd"), targetDescriptor: target, returnID: -1, transactionID: 0)
            event.setParam(try Self.propertySpecifier(property, container: container), forKeyword: Self.code("----"))
            let reply = try event.sendEvent(options: [.waitForReply, .neverInteract, .dontRecord], timeout: min(2, remaining))
            if let error = reply.paramDescriptor(forKeyword: Self.code("errn")), error.int32Value != 0 {
                throw Failure(code: Int(error.int32Value), message: "The music app could not provide playback.")
            }
            guard let value = reply.paramDescriptor(forKeyword: Self.code("----")) else {
                throw Failure(code: -1708, message: "Playback response was incomplete.")
            }
            return value
        }
        let state = try readProperty("player state").enumCodeValue
        guard state != dictionary.enumerators["stopped"] else { metadata[source] = nil; return nil }
        guard let currentTrack = dictionary.properties["current track"] else { throw Failure(code: -1708, message: "No current track property.") }
        let container = try Self.propertySpecifier(currentTrack)
        let identifier = source == .spotify ? "id" : "persistent id"
        let trackID = try readProperty(identifier, container: container).stringValue ?? ""
        guard !trackID.isEmpty else { return nil }
        var result: Playback
        if let cached = metadata[source], cached.processID == processID, cached.track.trackID == trackID, Date().timeIntervalSince(cached.date) < 30 {
            result = cached.track
        } else {
            let title = try readProperty("name", container: container).stringValue ?? ""
            let artist = try readProperty("artist", container: container).stringValue ?? ""
            let album = try readProperty("album", container: container).stringValue ?? ""
            let rawDuration = try readProperty("duration", container: container).doubleValue
            let duration = source == .spotify ? rawDuration / 1000 : rawDuration
            guard !title.isEmpty, duration.isFinite, duration > 0 else { return nil }
            result = Playback(source: source, trackID: trackID, title: title, artist: artist, album: album, duration: duration, position: 0, playing: false)
            metadata[source] = CachedTrack(processID: processID, track: result, date: Date())
        }
        let position = try readProperty("player position").doubleValue
        let sampledAt = ProcessInfo.processInfo.systemUptime
        // Track transitions between separate property reads must never mix two recordings.
        guard try readProperty(identifier, container: container).stringValue == trackID, position.isFinite else { return nil }
        result.position = max(0, position)
        result.playing = state == dictionary.enumerators["playing"]
        result.sampledAt = sampledAt
        return result
    }
    static func code(_ value: String) -> OSType { value.utf8.reduce(OSType(0)) { ($0 << 8) | OSType($1) } }
    static func propertySpecifier(_ property: OSType, container: NSAppleEventDescriptor? = nil) throws -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: code("prop")), forKeyword: code("want"))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: code("prop")), forKeyword: code("form"))
        record.setDescriptor(NSAppleEventDescriptor(typeCode: property), forKeyword: code("seld"))
        record.setDescriptor(container ?? .null(), forKeyword: code("from"))
        guard let result = record.coerce(toDescriptorType: code("obj ")) else { throw Failure(code: -1700, message: "Cannot construct a playback property request.") }
        return result
    }
}

/// Reads property codes from the installed vendor's dictionary instead of guessing Spotify codes.
final class ScriptingDictionary: NSObject, XMLParserDelegate {
    private(set) var properties: [String: OSType] = [:]
    private(set) var enumerators: [String: OSType] = [:]
    init(applicationURL: URL) throws {
        super.init()
        guard let bundle = Bundle(url: applicationURL), let resources = bundle.resourceURL,
              let definition = bundle.object(forInfoDictionaryKey: "OSAScriptingDefinition") as? String else {
            throw DesktopPlayer.Failure(code: -1708, message: "The music app has no scripting dictionary.")
        }
        let declared = resources.appendingPathComponent(definition)
        let candidates = [declared, resources.appendingPathComponent("applescript").appendingPathComponent(definition)]
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }), let parser = XMLParser(contentsOf: url) else {
            throw DesktopPlayer.Failure(code: -1708, message: "The music app's scripting dictionary is unavailable.")
        }
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        guard parser.parse(), properties["player position"] != nil, enumerators["playing"] != nil else {
            throw DesktopPlayer.Failure(code: -1708, message: "The music app's scripting dictionary is incomplete.")
        }
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        guard let name = attributes["name"]?.lowercased(), let raw = attributes["code"], raw.utf8.count == 4 else { return }
        if elementName == "property" { properties[name] = DesktopPlayer.code(raw) }
        if elementName == "enumerator" { enumerators[name] = DesktopPlayer.code(raw) }
    }
}
