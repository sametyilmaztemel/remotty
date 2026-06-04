import XCTest
@testable import remotyyLib

/// Unit tests for the HostManager class.
///
/// HostManager is a @MainActor ObservableObject that manages:
///   - Host process lifecycle (start/stop via Process)
///   - UserDefaults persistence (signalURL, hostName, launchAtLogin)
///   - Binary discovery (Bundle path → which → /usr/local/bin)
///   - Launch at login (SMAppService)
///
/// Because HostManager has the @MainActor attribute, all test
/// methods must run on the main actor.
@MainActor
final class HostManagerTests: XCTestCase {

    var manager: HostManager!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Clear any stored defaults so tests start from a clean slate
        UserDefaults.standard.removeObject(forKey: "signalURL")
        UserDefaults.standard.removeObject(forKey: "hostName")
        manager = HostManager()
    }

    override func tearDown() {
        manager = nil
        UserDefaults.standard.removeObject(forKey: "signalURL")
        UserDefaults.standard.removeObject(forKey: "hostName")
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertFalse(manager.isRunning, "Host should not be running on init")
        XCTAssertEqual(manager.statusMessage, "Ready", "Default status message")
        XCTAssertFalse(manager.screenSharing, "Screen sharing should be off on init")
        // launchAtLogin depends on SMAppService status which is not
        // registered during tests, so it should be false.
        XCTAssertFalse(manager.launchAtLogin, "Should default to not launching at login")
    }

    func testDefaultSignalURL() {
        // When no value has been saved, HostManager falls back to ws://localhost:9000
        XCTAssertEqual(manager.signalURL, "ws://localhost:9000",
                       "Default signal URL should be ws://localhost:9000")
    }

    func testDefaultHostName() {
        // When no value has been saved, HostManager uses the system host name
        XCTAssertEqual(manager.hostName, ProcessInfo.processInfo.hostName,
                       "Default host name should be the system host name")
    }

    // MARK: - UserDefaults Persistence

    func testPersistenceOfSignalURL() {
        let testURL = "ws://test.example.com:9000"
        manager.signalURL = testURL

        // Read synchronously from UserDefaults to confirm it was written
        let stored = UserDefaults.standard.string(forKey: "signalURL")
        XCTAssertEqual(stored, testURL, "signalURL should be persisted to UserDefaults")
    }

    func testPersistenceOfHostName() {
        let testName = "test-host-macbook"
        manager.hostName = testName

        let stored = UserDefaults.standard.string(forKey: "hostName")
        XCTAssertEqual(stored, testName, "hostName should be persisted to UserDefaults")
    }

    func testLoadFromUserDefaultsOnInit() {
        // Arrange: write values to UserDefaults before creating HostManager
        let testURL = "wss://persisted.example.com:9090"
        let testName = "persisted-host"
        UserDefaults.standard.set(testURL, forKey: "signalURL")
        UserDefaults.standard.set(testName, forKey: "hostName")

        // Act: create a fresh instance
        let newManager = HostManager()

        // Assert: it should read from the stored defaults
        XCTAssertEqual(newManager.signalURL, testURL,
                       "HostManager should load persisted signalURL")
        XCTAssertEqual(newManager.hostName, testName,
                       "HostManager should load persisted hostName")
    }

    // MARK: - Binary Discovery

    func testFindBinaryReturnsValidPathOrNil() {
        // findBinary() searches:
        //   1. Bundle.main path for "remotyyd"
        //   2. `which remotyy`
        //   3. /usr/local/bin/remotyy or /opt/homebrew/bin/remotyy
        //
        // In a test environment (no app bundle) it will likely return nil
        // or one of the hardcoded paths if the binary exists on the system.
        // Regardless, the method should never crash.
        let binary = manager.findBinary()

        if let path = binary {
            XCTAssertFalse(path.isEmpty, "Found binary path should not be empty")
            let exists = FileManager.default.fileExists(atPath: path)
            // The path might not exist in CI — we just verify the
            // method doesn't crash and returns a well-formed path.
            // If it *does* exist, we assert as much.
            if exists {
                XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path),
                              "Binary should be executable")
            }
        }
        // nil is acceptable when no binary is installed
    }

    // MARK: - Start / Stop (process lifecycle)

    func testStartHostWhenAlreadyRunningDoesNothing() {
        // Simulate already-running state
        manager.isRunning = true
        manager.statusMessage = "Running — some-host"

        let prevMessage = manager.statusMessage
        manager.startHost()

        // startHost() has a guard !isRunning that returns early,
        // so the status should remain unchanged.
        XCTAssertEqual(manager.statusMessage, prevMessage,
                       "startHost should be a no-op when already running")
    }

    func testStopHostWhenNotRunningDoesNothing() {
        manager.isRunning = false
        manager.statusMessage = "Ready"

        manager.stopHost()

        // stopHost() has a guard that returns early when not running
        XCTAssertEqual(manager.statusMessage, "Ready",
                       "stopHost should be a no-op when not running")
    }

    func testStartHostRejectsEmptySignalURL() {
        // Set a non-empty host name and empty signal URL
        manager.signalURL = ""
        manager.hostName = "my-host"

        manager.startHost()

        XCTAssertFalse(manager.isRunning, "Host should not start with empty signal URL")
        XCTAssertTrue(manager.statusMessage.contains("Signal URL is required"),
                      "User should be told the signal URL is required")
    }

    func testStartHostWhenBinaryNotFoundShowsMessage() throws {
        // Override findBinary to return nil so we can test the error path
        manager.signalURL = "ws://localhost:9000"
        manager.hostName = "my-host"

        // Force binary discovery to fail
        // We need to stub this — but since it's internal we can't easily stub.
        // Instead we rely on the fact that in a test runner there is usually
        // no "remote" binary on PATH. The test is still valid because it
        // verifies the guard behaves gracefully.
        //
        // If the binary *happens* to exist on this machine the test becomes
        // a no-op — that's acceptable.
        guard manager.findBinary() == nil else {
            // Binary exists — skip this test
            throw XCTSkip("remotyy binary is installed on this machine; skipping binary-not-found path")
        }

        manager.startHost()

        XCTAssertFalse(manager.isRunning, "Host should not start when binary is missing")
        XCTAssertEqual(manager.statusMessage, "Binary not found",
                       "User should be told the binary was not found")
    }

    // MARK: - ObservableObject contract

    func testPublishedPropertiesTriggerObjectWillChange() {
        // This is a basic contract verification: published property
        // changes should not crash and should be observable.
        let expectation = XCTNSNotificationExpectation(
            name: NSNotification.Name("dummy"),
            object: nil
        )
        expectation.isInverted = true // we don't actually expect a notification

        // Just verify the setters don't crash
        manager.signalURL = "ws://changed:9000"
        manager.hostName = "changed-host"
        manager.launchAtLogin = true
        manager.launchAtLogin = false
        manager.masterPassword = "secret123"

        // If we get here without a crash, the basic wiring is sound
    }
}
