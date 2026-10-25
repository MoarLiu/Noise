import Foundation

enum NoiseTimerMode: String, Codable, CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "专注"
        case .shortBreak:
            return "短休息"
        case .longBreak:
            return "长休息"
        }
    }

    var menuTitle: String {
        switch self {
        case .focus:
            return "专注"
        case .shortBreak:
            return "休息"
        case .longBreak:
            return "长休息"
        }
    }

    var systemImage: String {
        switch self {
        case .focus:
            return "timer"
        case .shortBreak:
            return "cup.and.saucer"
        case .longBreak:
            return "figure.walk"
        }
    }
}

enum NoiseRunState: String, Codable, Equatable {
    case idle
    case running
    case paused

    var title: String {
        switch self {
        case .idle:
            return "待开始"
        case .running:
            return "进行中"
        case .paused:
            return "已暂停"
        }
    }
}

struct NoiseSound: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var title: String
    var filename: String?

    static let none = NoiseSound(id: "none", title: "静音", filename: nil)

    var isNone: Bool {
        filename == nil || id == Self.none.id
    }

    var category: NoiseSoundCategory {
        guard !isNone else { return .none }
        let text = "\(title) \(filename ?? "")".lowercased()
        if text.contains("ocean") || text.contains("river") || text.contains("water") {
            return .water
        }
        if text.contains("rain") || text.contains("thunder") {
            return .rain
        }
        if text.contains("woods") || text.contains("forest") || text.contains("mountain") || text.contains("wind") || text.contains("hill") {
            return .nature
        }
        if text.contains("clock") || text.contains("timer") || text.contains("gong") {
            return .signals
        }
        return .ambient
    }
}

enum NoiseSoundCategory: String, CaseIterable, Identifiable {
    case none
    case water
    case rain
    case nature
    case ambient
    case signals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "静音"
        case .water:
            return "水声"
        case .rain:
            return "雨声"
        case .nature:
            return "自然"
        case .ambient:
            return "环境"
        case .signals:
            return "提示音"
        }
    }

    var systemImage: String {
        switch self {
        case .none:
            return "speaker.slash"
        case .water:
            return "water.waves"
        case .rain:
            return "cloud.rain"
        case .nature:
            return "leaf"
        case .ambient:
            return "waveform"
        case .signals:
            return "bell"
        }
    }
}

struct NoiseSettings: Codable, Equatable {
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var roundsUntilLongBreak: Int
    var autoStartNextRound: Bool
    var countdownInMenuBar: Bool
    var focusSoundID: String?
    var breakSoundID: String?
    var volume: Double
    var isMuted: Bool
    var fadeInSeconds: Double
    var fadeOutSeconds: Double
    var notificationsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case focusMinutes
        case shortBreakMinutes
        case longBreakMinutes
        case roundsUntilLongBreak
        case autoStartNextRound
        case countdownInMenuBar
        case focusSoundID
        case breakSoundID
        case volume
        case isMuted
        case fadeInSeconds
        case fadeOutSeconds
        case notificationsEnabled
    }

    static let standard = NoiseSettings(
        focusMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        roundsUntilLongBreak: 4,
        autoStartNextRound: false,
        countdownInMenuBar: true,
        focusSoundID: nil,
        breakSoundID: NoiseSound.none.id,
        volume: 0.38,
        fadeInSeconds: 1.2,
        fadeOutSeconds: 0.8,
        notificationsEnabled: true
    )

    init(
        focusMinutes: Int,
        shortBreakMinutes: Int,
        longBreakMinutes: Int,
        roundsUntilLongBreak: Int,
        autoStartNextRound: Bool,
        countdownInMenuBar: Bool,
        focusSoundID: String?,
        breakSoundID: String?,
        volume: Double,
        fadeInSeconds: Double,
        fadeOutSeconds: Double,
        notificationsEnabled: Bool,
        isMuted: Bool = false
    ) {
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.roundsUntilLongBreak = roundsUntilLongBreak
        self.autoStartNextRound = autoStartNextRound
        self.countdownInMenuBar = countdownInMenuBar
        self.focusSoundID = focusSoundID
        self.breakSoundID = breakSoundID
        self.volume = volume
        self.isMuted = isMuted
        self.fadeInSeconds = fadeInSeconds
        self.fadeOutSeconds = fadeOutSeconds
        self.notificationsEnabled = notificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let fallback = Self.standard
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? fallback.focusMinutes
        shortBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? fallback.shortBreakMinutes
        longBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? fallback.longBreakMinutes
        roundsUntilLongBreak = try container.decodeIfPresent(Int.self, forKey: .roundsUntilLongBreak) ?? fallback.roundsUntilLongBreak
        autoStartNextRound = try container.decodeIfPresent(Bool.self, forKey: .autoStartNextRound) ?? fallback.autoStartNextRound
        countdownInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .countdownInMenuBar) ?? fallback.countdownInMenuBar
        focusSoundID = try container.decodeIfPresent(String.self, forKey: .focusSoundID) ?? fallback.focusSoundID
        breakSoundID = try container.decodeIfPresent(String.self, forKey: .breakSoundID) ?? fallback.breakSoundID
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? fallback.volume
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        fadeInSeconds = try container.decodeIfPresent(Double.self, forKey: .fadeInSeconds) ?? fallback.fadeInSeconds
        fadeOutSeconds = try container.decodeIfPresent(Double.self, forKey: .fadeOutSeconds) ?? fallback.fadeOutSeconds
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? fallback.notificationsEnabled
    }

    var normalized: NoiseSettings {
        var copy = self
        copy.focusMinutes = min(max(copy.focusMinutes, 1), 180)
        copy.shortBreakMinutes = min(max(copy.shortBreakMinutes, 1), 60)
        copy.longBreakMinutes = min(max(copy.longBreakMinutes, 1), 90)
        copy.roundsUntilLongBreak = min(max(copy.roundsUntilLongBreak, 2), 12)
        copy.volume = min(max(copy.volume, 0), 1)
        copy.fadeInSeconds = min(max(copy.fadeInSeconds, 0), 8)
        copy.fadeOutSeconds = min(max(copy.fadeOutSeconds, 0), 8)
        return copy
    }
}

struct NoiseFocusRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var taskTitle: String
    var durationSeconds: Int
    var startedAt: Date
    var completedAt: Date

    init(
        id: UUID = UUID(),
        taskTitle: String,
        durationSeconds: Int,
        startedAt: Date,
        completedAt: Date
    ) {
        self.id = id
        self.taskTitle = taskTitle
        self.durationSeconds = max(durationSeconds, 1)
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    var displayTaskTitle: String {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名专注" : trimmed
    }

    var roundedMinutes: Int {
        max(1, Int((Double(durationSeconds) / 60.0).rounded()))
    }
}

struct NoiseCompletion: Equatable, Identifiable {
    var id = UUID()
    var mode: NoiseTimerMode
    var completedAt: Date
    var taskTitle: String
    var durationSeconds: Int
    var focusRecord: NoiseFocusRecord?

    var title: String {
        switch mode {
        case .focus:
            return "该休息一下了"
        case .shortBreak, .longBreak:
            return "休息结束"
        }
    }
}

struct NoiseTaskTally: Identifiable, Equatable {
    var id: String { title }
    var title: String
    var rounds: Int
    var totalSeconds: Int

    var roundedMinutes: Int {
        max(1, Int((Double(totalSeconds) / 60.0).rounded()))
    }
}

enum NoisePreset: String, CaseIterable, Identifiable {
    case classic
    case deepWork
    case writing
    case reading

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: return "经典"
        case .deepWork: return "深度"
        case .writing: return "写作"
        case .reading: return "阅读"
        }
    }

    var displayTitle: String { "\(name) · \(title)" }

    var title: String {
        switch self {
        case .classic:
            return "25 / 5"
        case .deepWork:
            return "50 / 10"
        case .writing:
            return "45 / 10"
        case .reading:
            return "30 / 5"
        }
    }

    var focusMinutes: Int {
        switch self {
        case .classic:
            return 25
        case .deepWork:
            return 50
        case .writing:
            return 45
        case .reading:
            return 30
        }
    }

    var shortBreakMinutes: Int {
        switch self {
        case .classic, .reading:
            return 5
        case .deepWork, .writing:
            return 10
        }
    }
}

enum NoiseSoundscapePreset: String, CaseIterable, Identifiable {
    case deepWork
    case rainyWriting
    case riversideReading
    case mountainReset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deepWork:
            return "深度工作"
        case .rainyWriting:
            return "雨天写作"
        case .riversideReading:
            return "河边阅读"
        case .mountainReset:
            return "山间复位"
        }
    }

    var detail: String {
        switch self {
        case .deepWork:
            return "海浪专注，休息静音"
        case .rainyWriting:
            return "轻雨专注，铃声收尾"
        case .riversideReading:
            return "河流声景，休息静音"
        case .mountainReset:
            return "山风环境，长时间任务"
        }
    }

    var focusKeywords: [String] {
        switch self {
        case .deepWork:
            return ["ocean", "waves"]
        case .rainyWriting:
            return ["rain", "falling"]
        case .riversideReading:
            return ["river", "duskfall"]
        case .mountainReset:
            return ["mountain", "wind"]
        }
    }

    var breakKeywords: [String]? {
        switch self {
        case .rainyWriting:
            return ["gong"]
        case .deepWork, .riversideReading, .mountainReset:
            return nil
        }
    }
}

struct NoiseExportSummary: Equatable {
    var message: String
    var url: URL
}
