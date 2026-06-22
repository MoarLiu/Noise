import AppKit
import Combine
import Foundation

final class NoiseStore: ObservableObject {
    private static let maxTaskTitleLength = 100
    private static let previewDurationSeconds: TimeInterval = 8

    private struct Payload: Codable {
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

    private struct LoadResult {
        var payload: Payload?
        var recoveryMessage: String?
    }

    @Published private(set) var settings: NoiseSettings
    @Published private(set) var mode: NoiseTimerMode
    @Published private(set) var state: NoiseRunState
    @Published private(set) var durationSeconds: Int
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var taskTitle: String
    @Published private(set) var records: [NoiseFocusRecord]
    @Published private(set) var completedFocusRoundsInCycle: Int
    @Published var lastCompletion: NoiseCompletion?
    @Published private(set) var persistenceError: String?
    @Published var exportSummary: NoiseExportSummary?
    @Published var exportErrorMessage: String?

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let audioPlayer = NoiseAudioPlayer()
    private let previewPlayer = NoiseAudioPlayer()
    private let notificationService: NoiseNotificationing
    private let dataDirectory: URL
    private let timerQueue = DispatchQueue(label: "com.crazyjal.noise.timer", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var activity: NSObjectProtocol?
    private var startedAt: Date?
    private var endDate: Date?
    private var isCompleting = false
    private var systemObservers: [NSObjectProtocol] = []
    private var previewStopWorkItem: DispatchWorkItem?

    var soundOptions: [NoiseSound] {
        NoiseSoundLibrary.options
    }

    var focusSound: NoiseSound {
        NoiseSoundLibrary.sound(for: settings.focusSoundID)
    }

    var breakSound: NoiseSound {
        NoiseSoundLibrary.soundForBreak(id: settings.breakSoundID)
    }

    var activeSound: NoiseSound {
        switch mode {
        case .focus:
            return focusSound
        case .shortBreak, .longBreak:
            return breakSound
        }
    }

    var progress: Double {
        guard durationSeconds > 0 else { return 0 }
        let completed = max(0, durationSeconds - remainingSeconds)
        return min(max(Double(completed) / Double(durationSeconds), 0), 1)
    }

    var todayRecords: [NoiseFocusRecord] {
        records.filter { Calendar.current.isDateInToday($0.completedAt) }
    }

    var sevenDayRecords: [NoiseFocusRecord] {
        records.records(inPastDays: 7)
    }

    var todayFocusSeconds: Int {
        todayRecords.reduce(0) { $0 + max(0, $1.durationSeconds) }
    }

    var sevenDayFocusSeconds: Int {
        sevenDayRecords.reduce(0) { $0 + max(0, $1.durationSeconds) }
    }

    var topTasks: [NoiseTaskTally] {
        Self.tallies(from: sevenDayRecords, limit: 5)
    }

    var recentTaskTitles: [String] {
        var seen = Set<String>()
        var titles: [String] = []
        for record in records {
            let title = record.displayTaskTitle
            guard !seen.contains(title) else { continue }
            seen.insert(title)
            titles.append(title)
            if titles.count == 8 { break }
        }
        return titles
    }

    var menuBarTitle: String? {
        guard settings.countdownInMenuBar, state != .idle else { return nil }
        let prefix = state == .paused ? "\(mode.menuTitle)暂停" : mode.menuTitle
        return "\(prefix) \(NoiseFormatters.clock(remainingSeconds))"
    }

    var menuBarSystemImage: String {
        switch state {
        case .idle:
            return "waveform"
        case .paused:
            return "pause.fill"
        case .running:
            return mode.systemImage
        }
    }

    var nextFocusRoundNumber: Int {
        min(completedFocusRoundsInCycle + 1, settings.roundsUntilLongBreak)
    }

    private var stateURL: URL {
        dataDirectory.appendingPathComponent("state.json")
    }

    init(dataDirectory: URL? = nil, notificationService: NoiseNotificationing = NoiseNotificationService()) {
        self.notificationService = notificationService
        self.dataDirectory = dataDirectory ?? Self.applicationSupportURL(fileManager: fileManager)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        decoder.dateDecodingStrategy = .iso8601

        let loaded = Self.loadPayload(from: self.dataDirectory.appendingPathComponent("state.json"), decoder: decoder, fileManager: fileManager)
        let payload = loaded.payload
        let settings = (payload?.settings ?? .standard).normalized
        let loadedMode = payload?.mode ?? .focus
        let loadedState = payload?.state ?? .idle
        let loadedDuration = max(payload?.durationSeconds ?? Self.durationSeconds(for: loadedMode, settings: settings), 1)
        self.settings = settings
        self.mode = loadedMode
        self.state = loadedState
        self.durationSeconds = loadedDuration
        self.remainingSeconds = max(payload?.remainingSeconds ?? loadedDuration, 0)
        self.taskTitle = Self.limitedTaskTitle(payload?.taskTitle ?? "")
        self.records = Self.filteredRecords(payload?.records ?? [])
        self.completedFocusRoundsInCycle = min(max(payload?.completedFocusRoundsInCycle ?? 0, 0), settings.roundsUntilLongBreak - 1)
        self.startedAt = payload?.startedAt
        self.endDate = payload?.endDate
        self.persistenceError = loaded.recoveryMessage

        normalizeLoadedTimer()
        registerSystemObservers()
        if state == .running {
            scheduleTimerIfNeeded()
            updateSoundPlayback()
        }
    }

    deinit {
        stopTimer()
        audioPlayer.stop(fadeOut: 0)
        previewPlayer.stop(fadeOut: 0)
        previewStopWorkItem?.cancel()
        for token in systemObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            NotificationCenter.default.removeObserver(token)
        }
    }

    func startFocus() {
        startSession(mode: .focus)
    }

    func startShortBreak() {
        startSession(mode: .shortBreak)
    }

    func startLongBreak() {
        startSession(mode: .longBreak)
    }

    func pause() {
        guard state == .running else { return }
        updateRemainingFromEndDate()
        state = .paused
        endDate = nil
        stopTimer()
        audioPlayer.stop(fadeOut: settings.fadeOutSeconds)
        save()
    }

    func resume() {
        guard state == .paused, remainingSeconds > 0 else { return }
        startedAt = startedAt ?? Date()
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        state = .running
        lastCompletion = nil
        save()
        scheduleTimerIfNeeded()
        updateSoundPlayback()
    }

    func stop() {
        stopTimer()
        audioPlayer.stop(fadeOut: settings.fadeOutSeconds)
        state = .idle
        mode = .focus
        startedAt = nil
        endDate = nil
        durationSeconds = Self.durationSeconds(for: mode, settings: settings)
        remainingSeconds = durationSeconds
        completedFocusRoundsInCycle = 0
        save()
    }

    func setTaskTitle(_ value: String) {
        let title = Self.limitedTaskTitle(value)
        guard taskTitle != title else { return }
        taskTitle = title
        save()
    }

    func useTaskTitle(_ value: String) {
        setTaskTitle(value)
        if state == .idle {
            startFocus()
        }
    }

    func applyPreset(_ preset: NoisePreset) {
        var next = settings
        next.focusMinutes = preset.focusMinutes
        next.shortBreakMinutes = preset.shortBreakMinutes
        settings = next.normalized
        syncIdleDurationIfNeeded()
        save()
    }

    func setFocusMinutes(_ value: Int) {
        updateSettings { $0.focusMinutes = value }
        syncIdleDurationIfNeeded()
    }

    func setShortBreakMinutes(_ value: Int) {
        updateSettings { $0.shortBreakMinutes = value }
        syncIdleDurationIfNeeded()
    }

    func setLongBreakMinutes(_ value: Int) {
        updateSettings { $0.longBreakMinutes = value }
        syncIdleDurationIfNeeded()
    }

    func setRoundsUntilLongBreak(_ value: Int) {
        updateSettings { $0.roundsUntilLongBreak = value }
        completedFocusRoundsInCycle = min(completedFocusRoundsInCycle, settings.roundsUntilLongBreak - 1)
        save()
    }

    func setAutoStartNextRound(_ value: Bool) {
        updateSettings { $0.autoStartNextRound = value }
    }

    func setCountdownInMenuBar(_ value: Bool) {
        updateSettings { $0.countdownInMenuBar = value }
    }

    func setNotificationsEnabled(_ value: Bool) {
        updateSettings { $0.notificationsEnabled = value }
        if value {
            notificationService.requestAuthorizationIfNeeded()
        }
    }

    func setFocusSound(_ sound: NoiseSound) {
        updateSettings { $0.focusSoundID = sound.id }
        updateSoundPlayback()
    }

    func setBreakSound(_ sound: NoiseSound) {
        updateSettings { $0.breakSoundID = sound.id }
        updateSoundPlayback()
    }

    func setVolume(_ value: Double) {
        updateSettings { $0.volume = value }
        audioPlayer.updateVolume(settings.volume)
    }

    func setFadeInSeconds(_ value: Double) {
        updateSettings { $0.fadeInSeconds = value }
    }

    func setFadeOutSeconds(_ value: Double) {
        updateSettings { $0.fadeOutSeconds = value }
    }

    func applySoundscape(_ preset: NoiseSoundscapePreset) {
        let focus = NoiseSoundLibrary.bestMatch(keywords: preset.focusKeywords)
        let breakSound = preset.breakKeywords.map { NoiseSoundLibrary.bestMatch(keywords: $0) } ?? .none
        updateSettings {
            $0.focusSoundID = focus.id
            $0.breakSoundID = breakSound.id
            $0.volume = preset.volume
        }
        updateSoundPlayback()
    }

    func previewFocusSound() {
        preview(sound: focusSound)
    }

    func previewBreakSound() {
        preview(sound: breakSound)
    }

    func exportRecordsCSV() {
        exportErrorMessage = nil
        exportSummary = nil
        do {
            exportSummary = try NoiseExportService.exportCSV(records: records)
        } catch {
            exportErrorMessage = "CSV 导出失败：\(error.localizedDescription)"
        }
    }

    func exportRecordsMarkdown() {
        exportErrorMessage = nil
        exportSummary = nil
        do {
            exportSummary = try NoiseExportService.exportMarkdown(records: records)
        } catch {
            exportErrorMessage = "Markdown 导出失败：\(error.localizedDescription)"
        }
    }

    func dismissExportStatus() {
        exportSummary = nil
        exportErrorMessage = nil
    }

    func dismissCompletion() {
        lastCompletion = nil
    }

    private func startSession(mode: NoiseTimerMode) {
        let seconds = Self.durationSeconds(for: mode, settings: settings)
        stopPreview()
        stopTimer()
        self.mode = mode
        state = .running
        durationSeconds = seconds
        remainingSeconds = seconds
        startedAt = Date()
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        lastCompletion = nil
        save()
        scheduleTimerIfNeeded()
        updateSoundPlayback()
    }

    private func completeCurrentSession() {
        guard !isCompleting else { return }
        isCompleting = true
        stopTimer()
        audioPlayer.stop(fadeOut: settings.fadeOutSeconds)

        let completedMode = mode
        let completedAt = Date()
        let completedStartedAt = startedAt ?? completedAt.addingTimeInterval(-TimeInterval(durationSeconds))
        let completedTaskTitle = taskTitle
        let completedDuration = durationSeconds
        var focusRecord: NoiseFocusRecord?

        if completedMode == .focus {
            let record = NoiseFocusRecord(
                taskTitle: completedTaskTitle,
                durationSeconds: completedDuration,
                startedAt: completedStartedAt,
                completedAt: completedAt
            )
            records.insert(record, at: 0)
            records = Self.filteredRecords(records)
            focusRecord = record
            completedFocusRoundsInCycle += 1
        }

        let transition = Self.nextModeAfterCompletion(
            completedMode: completedMode,
            completedFocusRoundsInCycle: completedFocusRoundsInCycle,
            settings: settings
        )
        completedFocusRoundsInCycle = transition.completedFocusRoundsInCycle
        let nextMode = transition.mode
        mode = nextMode
        state = .idle
        startedAt = nil
        endDate = nil
        durationSeconds = Self.durationSeconds(for: nextMode, settings: settings)
        remainingSeconds = durationSeconds
        let completion = NoiseCompletion(
            mode: completedMode,
            completedAt: completedAt,
            taskTitle: completedTaskTitle,
            durationSeconds: completedDuration,
            focusRecord: focusRecord
        )
        lastCompletion = completion
        save()

        if settings.notificationsEnabled {
            notificationService.deliver(
                completion: completion,
                nextMode: nextMode,
                autoStartNextRound: settings.autoStartNextRound
            )
        }

        if settings.autoStartNextRound {
            startSession(mode: nextMode)
        }
        isCompleting = false
    }

    private func nextModeAfterCompletion(of completedMode: NoiseTimerMode) -> NoiseTimerMode {
        let transition = Self.nextModeAfterCompletion(
            completedMode: completedMode,
            completedFocusRoundsInCycle: completedFocusRoundsInCycle,
            settings: settings
        )
        completedFocusRoundsInCycle = transition.completedFocusRoundsInCycle
        return transition.mode
    }

    private func scheduleTimerIfNeeded() {
        stopTimer()
        guard state == .running else { return }
        beginActivityIfNeeded()
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
        self.timer = timer
        timer.resume()
    }

    private func stopTimer() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
        endActivity()
    }

    private func tick() {
        guard state == .running else { return }
        updateRemainingFromEndDate()
        if remainingSeconds <= 0 {
            completeCurrentSession()
        }
    }

    private func updateRemainingFromEndDate() {
        guard let endDate else { return }
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(Date()))))
    }

    private func updateSoundPlayback() {
        guard state == .running else {
            audioPlayer.stop(fadeOut: settings.fadeOutSeconds)
            return
        }
        audioPlayer.play(activeSound, volume: settings.volume, fadeIn: settings.fadeInSeconds)
    }

    private func preview(sound: NoiseSound) {
        guard state != .running else { return }
        previewStopWorkItem?.cancel()
        previewPlayer.play(sound, volume: settings.volume, fadeIn: 0.2)
        let workItem = DispatchWorkItem { [weak self] in
            self?.previewPlayer.stop(fadeOut: 0.3)
            self?.previewStopWorkItem = nil
        }
        previewStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.previewDurationSeconds, execute: workItem)
    }

    private func stopPreview() {
        previewStopWorkItem?.cancel()
        previewStopWorkItem = nil
        previewPlayer.stop(fadeOut: 0.2)
    }

    private func updateSettings(_ mutate: (inout NoiseSettings) -> Void) {
        var next = settings
        mutate(&next)
        settings = next.normalized
        save()
    }

    private func syncIdleDurationIfNeeded() {
        guard state == .idle else { return }
        durationSeconds = Self.durationSeconds(for: mode, settings: settings)
        remainingSeconds = durationSeconds
        save()
    }

    private func normalizeLoadedTimer() {
        if state == .running, let endDate {
            remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(Date()))))
            if remainingSeconds <= 0 {
                finishElapsedLoadedSession(completedAt: endDate)
            }
        } else if state == .running {
            state = .idle
            mode = .focus
            durationSeconds = Self.durationSeconds(for: mode, settings: settings)
            remainingSeconds = durationSeconds
        } else if state == .idle {
            durationSeconds = Self.durationSeconds(for: mode, settings: settings)
            remainingSeconds = durationSeconds
            startedAt = nil
            endDate = nil
        } else if state == .paused {
            endDate = nil
        }
    }

    private func finishElapsedLoadedSession(completedAt: Date) {
        let completedMode = mode
        let completedStartedAt = startedAt ?? completedAt.addingTimeInterval(-TimeInterval(durationSeconds))
        let completedTaskTitle = taskTitle
        let completedDuration = durationSeconds
        var focusRecord: NoiseFocusRecord?

        if completedMode == .focus {
            let record = NoiseFocusRecord(
                taskTitle: completedTaskTitle,
                durationSeconds: completedDuration,
                startedAt: completedStartedAt,
                completedAt: completedAt
            )
            records.insert(record, at: 0)
            records = Self.filteredRecords(records)
            completedFocusRoundsInCycle += 1
            focusRecord = record
        }

        let transition = Self.nextModeAfterCompletion(
            completedMode: completedMode,
            completedFocusRoundsInCycle: completedFocusRoundsInCycle,
            settings: settings
        )
        completedFocusRoundsInCycle = transition.completedFocusRoundsInCycle
        mode = transition.mode
        state = .idle
        startedAt = nil
        self.endDate = nil
        durationSeconds = Self.durationSeconds(for: mode, settings: settings)
        remainingSeconds = durationSeconds

        let completion = NoiseCompletion(
            mode: completedMode,
            completedAt: completedAt,
            taskTitle: completedTaskTitle,
            durationSeconds: completedDuration,
            focusRecord: focusRecord
        )
        lastCompletion = completion
        save()

        if settings.notificationsEnabled {
            notificationService.deliver(
                completion: completion,
                nextMode: mode,
                autoStartNextRound: false
            )
        }
    }

    private func registerSystemObservers() {
        let handler: (Notification) -> Void = { [weak self] _ in
            guard let self else { return }
            self.tick()
            if self.state == .running {
                self.scheduleTimerIfNeeded()
            }
        }

        systemObservers.append(
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main,
                using: handler
            )
        )

        for name in [Notification.Name.NSSystemClockDidChange, Notification.Name.NSSystemTimeZoneDidChange] {
            systemObservers.append(
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main,
                    using: handler
                )
            )
        }
    }

    private func beginActivityIfNeeded() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Noise timer is running"
        )
    }

    private func endActivity() {
        guard let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
    }

    private func save() {
        do {
            let directory = stateURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let payload = Payload(
                version: 1,
                settings: settings,
                mode: mode,
                state: state,
                durationSeconds: durationSeconds,
                remainingSeconds: remainingSeconds,
                taskTitle: taskTitle,
                records: records,
                startedAt: startedAt,
                endDate: endDate,
                completedFocusRoundsInCycle: completedFocusRoundsInCycle
            )
            let data = try encoder.encode(payload)
            try data.write(to: stateURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private static func loadPayload(from url: URL, decoder: JSONDecoder, fileManager: FileManager) -> LoadResult {
        guard fileManager.fileExists(atPath: url.path) else {
            return LoadResult(payload: nil, recoveryMessage: nil)
        }

        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                throw NSError(domain: "NoisePersistence", code: 1, userInfo: [NSLocalizedDescriptionKey: "state.json is empty."])
            }
            return LoadResult(payload: try decoder.decode(Payload.self, from: data), recoveryMessage: nil)
        } catch {
            let backupURL = backupURL(forUnreadableStateAt: url)
            do {
                try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: backupURL.path) {
                    try? fileManager.removeItem(at: backupURL)
                }
                try fileManager.copyItem(at: url, to: backupURL)
                try fileManager.removeItem(at: url)
                let message = "状态文件无法读取，已备份为 \(backupURL.lastPathComponent)。"
                NSLog("Noise recovered unreadable state: \(error.localizedDescription); backup: \(backupURL.path)")
                return LoadResult(payload: nil, recoveryMessage: message)
            } catch {
                let message = "状态文件无法读取，且备份失败：\(error.localizedDescription)"
                NSLog("Noise failed to back up unreadable state: \(error.localizedDescription)")
                return LoadResult(payload: nil, recoveryMessage: message)
            }
        }
    }

    private static func applicationSupportURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Noise", isDirectory: true)
    }

    private static func durationSeconds(for mode: NoiseTimerMode, settings: NoiseSettings) -> Int {
        switch mode {
        case .focus:
            return settings.focusMinutes * 60
        case .shortBreak:
            return settings.shortBreakMinutes * 60
        case .longBreak:
            return settings.longBreakMinutes * 60
        }
    }

    static func nextModeAfterCompletion(
        completedMode: NoiseTimerMode,
        completedFocusRoundsInCycle: Int,
        settings: NoiseSettings
    ) -> (mode: NoiseTimerMode, completedFocusRoundsInCycle: Int) {
        switch completedMode {
        case .focus:
            if completedFocusRoundsInCycle >= settings.roundsUntilLongBreak {
                return (.longBreak, 0)
            }
            return (.shortBreak, completedFocusRoundsInCycle)
        case .shortBreak, .longBreak:
            return (.focus, completedFocusRoundsInCycle)
        }
    }

    private static func limitedTaskTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxTaskTitleLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxTaskTitleLength)
        return String(trimmed[..<index])
    }

    private static func filteredRecords(_ records: [NoiseFocusRecord], now: Date = Date()) -> [NoiseFocusRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
        return Array(records.filter { $0.completedAt >= cutoff }
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(1000))
    }

    private static func tallies(from records: [NoiseFocusRecord], limit: Int) -> [NoiseTaskTally] {
        var tallies: [String: NoiseTaskTally] = [:]
        for record in records {
            let title = record.displayTaskTitle
            var tally = tallies[title] ?? NoiseTaskTally(title: title, rounds: 0, totalSeconds: 0)
            tally.rounds += 1
            tally.totalSeconds += max(0, record.durationSeconds)
            tallies[title] = tally
        }
        return Array(tallies.values.sorted { lhs, rhs in
            if lhs.rounds != rhs.rounds { return lhs.rounds > rhs.rounds }
            if lhs.totalSeconds != rhs.totalSeconds { return lhs.totalSeconds > rhs.totalSeconds }
            return lhs.title < rhs.title
        }.prefix(max(0, limit)))
    }

    private static func backupURL(forUnreadableStateAt url: URL, now: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: now)
        return url.deletingLastPathComponent()
            .appendingPathComponent("state-unreadable-\(stamp).json")
    }
}

private extension Array where Element == NoiseFocusRecord {
    func records(inPastDays days: Int, now: Date = Date(), calendar: Calendar = .current) -> [NoiseFocusRecord] {
        let span = Swift.max(days - 1, 0)
        let start = calendar.date(byAdding: .day, value: -span, to: calendar.startOfDay(for: now)) ?? now
        return filter { $0.completedAt >= start && $0.completedAt <= now }
    }
}
