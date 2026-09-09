import AppKit
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
        try run("manual rest starts the break selected by the cycle", manualRestHonorsCycle)
        try run("pause at deadline completes once with either auto-start setting", pauseAtDeadlineCompletesOnce)
        try run("pause and resume preserve remaining focus time", pauseAndResumePreserveRemainingTime)
        try run("wake after midnight records the original deadline", delayedWakeRecordsOriginalDeadline)
        try run("zero-second paused state is recovered once", zeroSecondPausedStateIsRecoveredOnce)
        try run("replay during fade-out cancels the old stop", replayDuringFadeOutCancelsOldStop)
        try run("resume stops preview before starting session audio", resumeStopsPreviewBeforeSessionAudio)
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

private func manualRestHonorsCycle() throws {
    for previousRounds in [0, 3] {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = TestClock()
        let settings = quietSettings()
        try writeState(
            in: directory,
            mode: .focus,
            state: .running,
            durationSeconds: 1_500,
            remainingSeconds: 1,
            taskTitle: "Cycle review",
            startedAt: clock.date.addingTimeInterval(-1_600),
            endDate: clock.date.addingTimeInterval(-100),
            completedFocusRoundsInCycle: previousRounds,
            settings: settings
        )
        let store = NoiseStore(dataDirectory: directory, notificationService: FakeNotificationService(), now: { clock.date })
        defer { store.stop() }
        let expectedMode: NoiseTimerMode = previousRounds == 3 ? .longBreak : .shortBreak
        let expectedDuration = (previousRounds == 3 ? settings.longBreakMinutes : settings.shortBreakMinutes) * 60

        try expect(store.mode == expectedMode, "completion should prepare the appropriate break")
        store.startBreak()

        try expect(store.state == .running, "manual rest should start the prepared break")
        try expect(store.mode == expectedMode, "manual rest must preserve a scheduled long break")
        try expect(store.remainingSeconds == expectedDuration, "rest should use the appropriate configured duration")
        try expect(store.completedFocusRoundsInCycle == (previousRounds == 3 ? 0 : 1), "starting rest should preserve the cycle count")
    }
}

private func pauseAtDeadlineCompletesOnce() throws {
    for autoStart in [false, true] {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = TestClock()
        let notifications = FakeNotificationService()
        let store = NoiseStore(dataDirectory: directory, notificationService: notifications, now: { clock.date })
        defer { store.stop() }
        store.setFocusSound(.none)
        store.setAutoStartNextRound(autoStart)
        store.startFocus()
        let deadline = clock.date.addingTimeInterval(TimeInterval(store.durationSeconds))
        clock.date = deadline

        store.pause()

        try expect(store.state == (autoStart ? .running : .idle), "elapsed focus should complete instead of entering a zero-second pause")
        try expect(store.mode == .shortBreak, "elapsed focus should transition to rest")
        try expect(store.remainingSeconds == store.settings.shortBreakMinutes * 60, "the next round should have its full duration")
        try expect(store.records.count == 1, "elapsed focus should create exactly one record")
        try expect(store.records.first?.completedAt == deadline, "pause at deadline should preserve the completion timestamp")
        try expect(notifications.deliveries.count == 1, "elapsed focus should notify once")

        // Simulate a timer/wake event that was queued before the pause action.
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        store.resume()
        try expect(store.records.count == 1, "a queued event or resume action must not duplicate the completed focus")
        try expect(notifications.deliveries.count == 1, "a queued event must not notify twice")
    }
}

private func pauseAndResumePreserveRemainingTime() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let clock = TestClock()
    let store = NoiseStore(dataDirectory: directory, notificationService: FakeNotificationService(), now: { clock.date })
    defer { store.stop() }
    store.setFocusSound(.none)
    store.startFocus()
    clock.date.addTimeInterval(10)
    store.pause()
    try expect(store.state == .paused && store.remainingSeconds == 1_490, "pause before deadline should preserve the remaining focus")
    try expect(store.records.isEmpty, "pausing an unfinished focus must not record completion")

    clock.date.addTimeInterval(100)
    store.resume()
    try expect(store.state == .running && store.remainingSeconds == 1_490, "time spent paused must not consume remaining focus")
    clock.date.addTimeInterval(1_490)
    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    try expect(store.records.count == 1, "resumed focus should complete once")
    try expect(store.records.first?.completedAt == clock.date, "resumed focus should use its updated deadline")
    try expect(store.records.first?.durationSeconds == 1_500, "pause time must not inflate recorded focus duration")
}

private func delayedWakeRecordsOriginalDeadline() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let midnight = Calendar.current.startOfDay(for: Date())
    let clock = TestClock(date: midnight.addingTimeInterval(-30 * 60))
    let notifications = FakeNotificationService()
    let store = NoiseStore(dataDirectory: directory, notificationService: notifications, now: { clock.date })
    defer { store.stop() }
    store.setFocusSound(.none)
    store.startFocus()
    let deadline = clock.date.addingTimeInterval(TimeInterval(store.durationSeconds))
    clock.date = midnight.addingTimeInterval(8 * 60 * 60)

    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)

    try expect(store.records.count == 1, "delayed wake should settle the elapsed focus once")
    try expect(store.records.first?.completedAt == deadline, "completion should use the deadline before midnight, not the wake time")
    try expect(store.todayRecords.isEmpty, "yesterday's focus must not be counted as today's focus")
    try expect(notifications.deliveries.first?.0.completedAt == deadline, "notification should use the same completion timestamp as the record")
    let csv = NoiseExportService.csvString(records: store.records)
    try expect(csv.contains(NoiseFormatters.iso8601.string(from: deadline)), "export should retain the original deadline")
}

private func zeroSecondPausedStateIsRecoveredOnce() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let clock = TestClock()
    try writeState(
        in: directory,
        mode: .focus,
        state: .paused,
        durationSeconds: 1_500,
        remainingSeconds: 0,
        taskTitle: "Previously stuck focus",
        startedAt: clock.date.addingTimeInterval(-1_500),
        endDate: nil,
        completedFocusRoundsInCycle: 0,
        settings: quietSettings()
    )
    let store = NoiseStore(dataDirectory: directory, notificationService: FakeNotificationService(), now: { clock.date })
    try expect(store.state == .idle && store.mode == .shortBreak, "a previously persisted zero-second pause should recover into rest")
    try expect(store.records.count == 1, "the completed but stuck focus should be recorded")
    let restored = NoiseStore(dataDirectory: directory, notificationService: FakeNotificationService(), now: { clock.date })
    try expect(restored.records.count == 1, "relaunch must not record the recovered focus twice")
}

private func replayDuringFadeOutCancelsOldStop() throws {
    let backend = FakeAudioPlayback()
    var createdPlayers = 0
    let audio = NoiseAudioPlayer { _ in
        createdPlayers += 1
        return backend
    }
    let sound = try availableTestSound()
    audio.play(sound, volume: 0.4, fadeIn: 0)
    audio.stop(fadeOut: 0.05)
    audio.play(sound, volume: 0.4, fadeIn: 0)
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))

    try expect(createdPlayers == 1, "resuming the same sound should reuse the active player")
    try expect(backend.isPlaying, "the old fade-out callback must not stop resumed playback")
    try expect(backend.stopCount == 0, "resuming should invalidate the old stop operation")
    try expect(backend.volume == 0.4, "resuming should restore the requested volume")

    audio.stop(fadeOut: 0.05)
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    try expect(!backend.isPlaying && backend.stopCount == 1, "a subsequent intentional fade-out should still stop playback")
}

private func resumeStopsPreviewBeforeSessionAudio() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let clock = TestClock()
    let sessionBackend = FakeAudioPlayback()
    let previewBackend = FakeAudioPlayback()
    let store = NoiseStore(
        dataDirectory: directory,
        notificationService: FakeNotificationService(),
        audioPlayer: NoiseAudioPlayer { _ in sessionBackend },
        previewPlayer: NoiseAudioPlayer { _ in previewBackend },
        now: { clock.date }
    )
    defer { store.stop() }
    let sound = try availableTestSound()
    store.setFocusSound(sound)
    store.setBreakSound(sound)
    store.setFadeOutSeconds(0)
    store.startFocus()
    clock.date.addTimeInterval(10)
    store.pause()
    store.previewBreakSound()
    try expect(previewBackend.isPlaying && !sessionBackend.isPlaying, "only the preview should play while paused")
    var previewWasStoppedBeforePlayback = false
    sessionBackend.onPlay = { previewWasStoppedBeforePlayback = !previewBackend.isPlaying }

    store.resume()

    try expect(previewWasStoppedBeforePlayback, "resume must stop the preview before starting session audio")
    try expect(sessionBackend.isPlaying && !previewBackend.isPlaying, "only the session sound should play after resume")
    try expect(store.state == .running && store.remainingSeconds == 1_490, "stopping a preview must not reset the resumed timer")
}

private func quietSettings() -> NoiseSettings {
    var settings = NoiseSettings.standard
    settings.focusSoundID = NoiseSound.none.id
    settings.breakSoundID = NoiseSound.none.id
    settings.notificationsEnabled = false
    return settings
}

private func availableTestSound() throws -> NoiseSound {
    let sound = NoiseSoundLibrary.sound(for: nil)
    try expect(!sound.isNone && NoiseSoundLibrary.url(for: sound) != nil, "audio tests require a bundled sound URL")
    return sound
}

private final class TestClock {
    var date: Date

    init(date: Date = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))) {
        self.date = date
    }
}

private final class FakeAudioPlayback: NoiseAudioPlayback {
    private(set) var isPlaying = false
    private(set) var stopCount = 0
    var numberOfLoops = 0
    var volume: Float = 0
    var onPlay: (() -> Void)?

    func prepareToPlay() -> Bool { true }

    func play() -> Bool {
        onPlay?()
        isPlaying = true
        return true
    }

    func stop() {
        stopCount += 1
        isPlaying = false
    }

    func setVolume(_ volume: Float, fadeDuration: TimeInterval) {
        self.volume = volume
    }
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
