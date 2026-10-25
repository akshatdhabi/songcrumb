import XCTest
final class SongcrumbCoreTests: XCTestCase {
    func testSyncAndSelectionRequirements() throws { try CoreChecks().run() }
}
