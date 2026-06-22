import Foundation

@main
struct NoiseCoreTestRunner {
    static func main() throws {
        try run("expired running focus is recorded on launch", expiredRunningFocusIsRecordedOnLaunch)
        try run("unreadable state is backed up before new state is saved", unreadableStateIsBackedUpBeforeNewStateIsSaved)
        try run("break sound missing id falls back to silence", breakSoundMissingIDFallsBackToSilence)
        try run("export strings contain expected record data", exportStringsContainExpectedRecordData)
        try run("long break transition resets cycle count", longBreakTransitionResetsCycleCount)
        try run("notification authorization is not requested on plain launch", notificationAuthorizationIsNotRequestedOnPlainLaunch)
        try run("menu bar status reflects paused restored timer", menuBarStatusReflectsPausedRestoredTimer)
        print("All Noise self-tests passed.")
    }

    private static func run(_ name: String, _ test: () throws -> Void) throws {
        do {
            try test()
            print("PASS \(name)")
        } catch {
            print("FAIL \(name): \(error.localizedDescription)")
            throw error
        }
    }
}

private struct TestFailure: Error, LocalizedError {
    var message: String

    var errorDescription: String? {
        message
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw TestFailure(message: message)
    }
}

private func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else {
        throw TestFailure(message: message)
    }
    return value
}

private func expiredRunningFocusIsRecordedOnLaunch() throws {
    let directory = try makeTemporaryDirectory()
    let startedAt = Date(timeIntervalSinceNow: -1_600)
    let endedAt = Date(timeIntervalSinceNow: -100)
    try writeState(
        in: directory,
        mode: .focus,
        state: .running,
        durationSeconds: 1_500,
        remainingSeconds: 1,
        taskTitle: "Write review",
        startedAt: startedAt,
        endDate: endedAt,
        completedFocusRoundsInCycle: 0,
        settings: .standard
    )

    let notifications = FakeNotificationService()
    let store = NoiseStore(dataDirectory: directory, notificationService: notifications)

    try expect(store.state == .idle, "store should return to idle after completing restored timer")
    try expect(store.mode == .shortBreak, "next mode should be short break")
    try expect(store.records.count == 1, "restored focus should create one record")
    try expect(store.records.first?.displayTaskTitle == "Write review", "record task title should be preserved")
    let completedAt = try require(store.records.first?.completedAt, "record completion date should exist")
    try expect(abs(completedAt.timeIntervalSince(endedAt)) < 1.1, "record completion date should use persisted end date")
    try expect(notifications.deliveries.count == 1, "restored completion should send one notification")
}

private func unreadableStateIsBackedUpBeforeNewStateIsSaved() throws {
    let directory = try makeTemporaryDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let stateURL = directory.appendingPathComponent("state.json")
    try Data("not json".utf8).write(to: stateURL)

    let store = NoiseStore(dataDirectory: directory, notificationService: FakeNotificationService())

    try expect(store.persistenceError != nil, "corrupt state should surface a persistence error")
    try expect(!FileManager.default.fileExists(atPath: stateURL.path), "corrupt state should be moved out of the active path")
    let backupsAfterLoad = try unreadableBackups(in: directory)
    try expect(backupsAfterLoad.count == 1, "corrupt state should be backed up")

    store.setTaskTitle("Recovered")

    try expect(FileManager.default.fileExists(atPath: stateURL.path), "new state should be saved after backup")
    let backupsAfterSave = try unreadableBackups(in: directory)
    try expect(backupsAfterSave.count == 1, "backup should remain after saving new state")
}

private func breakSoundMissingIDFallsBackToSilence() throws {
    try expect(NoiseSoundLibrary.soundForBreak(id: "missing-file.mp3").isNone, "missing break sound should resolve to silence")
}

private func exportStringsContainExpectedRecordData() throws {
    let record = NoiseFocusRecord(
        taskTitle: "Write, \"Review\"",
        durationSeconds: 1_500,
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        completedAt: Date(timeIntervalSince1970: 1_700_001_500)
    )

    let csv = NoiseExportService.csvString(records: [record])
    try expect(csv.contains("\"Write, \"\"Review\"\"\""), "csv should escape task title")
    try expect(csv.contains(",25,1500"), "csv should include minutes and seconds")

    let markdown = NoiseExportService.markdownString(records: [record])
    try expect(markdown.contains("Noise 专注复盘"), "markdown should include report title")
    try expect(markdown.contains("Write, \"Review\""), "markdown should include task title")
    try expect(markdown.contains("25 分钟"), "markdown should include rounded minutes")
}

private func longBreakTransitionResetsCycleCount() throws {
    var settings = NoiseSettings.standard
    settings.roundsUntilLongBreak = 4

    let longBreak = NoiseStore.nextModeAfterCompletion(
        completedMode: .focus,
        completedFocusRoundsInCycle: 4,
        settings: settings
    )
    try expect(longBreak.mode == .longBreak, "fourth focus should enter long break")
    try expect(longBreak.completedFocusRoundsInCycle == 0, "long break should reset cycle count")

    let shortBreak = NoiseStore.nextModeAfterCompletion(
        completedMode: .focus,
        completedFocusRoundsInCycle: 3,
        settings: settings
    )
    try expect(shortBreak.mode == .shortBreak, "non-threshold focus should enter short break")
    try expect(shortBreak.completedFocusRoundsInCycle == 3, "short break should preserve cycle count")
}

private func notificationAuthorizationIsNotRequestedOnPlainLaunch() throws {
    let directory = try makeTemporaryDirectory()
    let notifications = FakeNotificationService()

    _ = NoiseStore(dataDirectory: directory, notificationService: notifications)

    try expect(notifications.authorizationRequests == 0, "plain launch should not request notification authorization")
    try expect(notifications.deliveries.isEmpty, "plain launch should not send notifications")
}

private func menuBarStatusReflectsPausedRestoredTimer() throws {
    let directory = try makeTemporaryDirectory()
    try writeState(
        in: directory,
        mode: .focus,
        state: .paused,
        durationSeconds: 1_500,
        remainingSeconds: 870,
        taskTitle: "Menu bar review",
        startedAt: Date(timeIntervalSinceNow: -630),
        endDate: nil,
        completedFocusRoundsInCycle: 2,
        settings: .standard
    )

    let store = NoiseStore(dataDirectory: directory, notificationService: FakeNotificationService())

    try expect(store.menuBarTitle == "专注暂停 14:30", "paused timer should show mode and remaining time")
    try expect(store.menuBarSystemImage == "pause.fill", "paused timer should use pause menu bar icon")
    try expect(store.nextFocusRoundNumber == 3, "restored round number should be one-based")

    store.setCountdownInMenuBar(false)
    try expect(store.menuBarTitle == nil, "disabled countdown should hide menu bar countdown title")

    store.stop()
    try expect(store.menuBarSystemImage == "waveform", "idle timer should use default menu bar icon")
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("NoiseTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func unreadableBackups(in directory: URL) throws -> [URL] {
    try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix("state-unreadable-") }
}

private func writeState(
    in directory: URL,
    mode: NoiseTimerMode,
    state: NoiseRunState,
    durationSeconds: Int,
    remainingSeconds: Int,
    taskTitle: String,
    startedAt: Date?,
    endDate: Date?,
    completedFocusRoundsInCycle: Int,
    settings: NoiseSettings
) throws {
    struct TestPayload: Encodable {
        var version: Int
        var settings: NoiseSettings
        var mode: NoiseTimerMode
        var state: NoiseRunState
        var durationSeconds: Int
        var remainingSeconds: Int
        var taskTitle: String
        var records: [NoiseFocusRecord]
        var startedAt: Date?
        var endDate: Date?
        var completedFocusRoundsInCycle: Int
    }

    let payload = TestPayload(
        version: 1,
        settings: settings,
        mode: mode,
        state: state,
        durationSeconds: durationSeconds,
        remainingSeconds: remainingSeconds,
        taskTitle: taskTitle,
        records: [],
        startedAt: startedAt,
        endDate: endDate,
        completedFocusRoundsInCycle: completedFocusRoundsInCycle
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(payload).write(to: directory.appendingPathComponent("state.json"), options: .atomic)
}

private final class FakeNotificationService: NoiseNotificationing {
    private(set) var authorizationRequests = 0
    private(set) var deliveries: [(NoiseCompletion, NoiseTimerMode, Bool)] = []

    func requestAuthorizationIfNeeded() {
        authorizationRequests += 1
    }

    func deliver(completion: NoiseCompletion, nextMode: NoiseTimerMode, autoStartNextRound: Bool) {
        deliveries.append((completion, nextMode, autoStartNextRound))
    }
}
