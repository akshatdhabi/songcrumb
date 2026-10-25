import Foundation
import Network

final class BrowserBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "io.github.akshatdhabi.songcrumb.browser", qos: .utility)
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var generation = UUID()
    private let port: NWEndpoint.Port
    init(port: UInt16 = 48537) { self.port = NWEndpoint.Port(rawValue: port)! }
    var onPlayback: (@Sendable (Playback?) -> Void)?
    var onStatus: (@Sendable (String) -> Void)?
    func start(token: String) {
        queue.async { [self] in
            guard listener == nil else { return }
            do {
                let parameters = NWParameters.tcp
                parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
                let server = try NWListener(using: parameters)
                listener = server
                let current = generation
                server.stateUpdateHandler = { [weak self] state in
                    guard let self, self.generation == current else { return }
                    switch state {
                    case .ready: self.onStatus?("Ready on this Mac · waiting for browser")
                    case .failed(let error):
                        self.onStatus?("Browser bridge: \(error.localizedDescription). Toggle YouTube Music to retry.")
                        self.stopOnQueue()
                    default: break
                    }
                }
                server.newConnectionHandler = { [weak self] connection in
                    guard let self, self.generation == current, self.connections.count < 8 else { connection.cancel(); return }
                    let id = UUID()
                    self.connections[id] = connection
                    connection.start(queue: self.queue)
                    self.queue.asyncAfter(deadline: .now() + 3) { [weak self] in self?.finish(id) }
                    self.receive(connection, id: id, data: Data(), token: token)
                }
                server.start(queue: queue)
            } catch { onStatus?("Browser bridge could not start: \(error.localizedDescription)") }
        }
    }
    func stop() { queue.async { [self] in stopOnQueue() } }
    private func stopOnQueue() {
        generation = UUID()
        listener?.cancel(); listener = nil
        connections.values.forEach { $0.cancel() }; connections.removeAll()
    }
    private func finish(_ id: UUID) { connections.removeValue(forKey: id)?.cancel() }
    private func receive(_ connection: NWConnection, id: UUID, data: Data, token: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] chunk, _, complete, error in
            guard let self, self.connections[id] != nil else { return }
            var buffer = data; if let chunk { buffer.append(chunk) }
            switch BridgeRequest.parse(buffer, token: token, port: self.port.rawValue) {
            case .incomplete:
                if complete || error != nil { self.finish(id) }
                else { self.receive(connection, id: id, data: buffer, token: token) }
            case .rejected(let status):
                self.reply(connection, id: id, status: status)
            case .accepted(let track):
                self.onPlayback?(track)
                self.onStatus?(track == nil ? "Browser connected · no song or advertisement" : "YouTube Music connected")
                self.reply(connection, id: id, status: "200 OK")
            }
        }
    }
    private func reply(_ connection: NWConnection, id: UUID, status: String) {
        let response = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] _ in self?.finish(id) })
    }
}
