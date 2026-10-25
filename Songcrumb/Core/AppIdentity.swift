import Foundation

enum AppIdentity {
    static let name = "Songcrumb"
    static let version = "1.1.0"
    static let projectURL = URL(string: "https://github.com/akshatdhabi/songcrumb")!
    static var userAgent: String { "\(name)/\(version) (\(projectURL.absoluteString))" }
}
