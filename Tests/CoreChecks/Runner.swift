import Foundation
@main struct Runner {
    static func main() {
        do { try CoreChecks().run() }
        catch { fputs("Core test failure: \(error)\n", stderr); exit(1) }
    }
}
