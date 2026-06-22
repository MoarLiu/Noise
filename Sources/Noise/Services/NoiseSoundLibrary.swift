import Foundation

enum NoiseSoundLibrary {
    static let supportedExtensions = Set(["mp3", "m4a", "aiff", "aif", "wav"])

    static var options: [NoiseSound] {
        [.none] + bundledSounds()
    }

    static var groupedOptions: [(category: NoiseSoundCategory, sounds: [NoiseSound])] {
        let allOptions = options
        return NoiseSoundCategory.allCases.compactMap { category in
            let sounds = allOptions.filter { $0.category == category }
            return sounds.isEmpty ? nil : (category, sounds)
        }
    }

    static func sound(for id: String?) -> NoiseSound {
        let allOptions = options
        guard let id, id != NoiseSound.none.id else {
            return id == NoiseSound.none.id ? .none : defaultFocusSound(from: allOptions)
        }

        return allOptions.first { $0.id == id || $0.filename == id }
            ?? defaultFocusSound(from: allOptions)
    }

    static func soundForBreak(id: String?) -> NoiseSound {
        guard let id, id != NoiseSound.none.id else { return .none }
        return options.first { $0.id == id || $0.filename == id } ?? .none
    }

    static func bestMatch(keywords: [String]) -> NoiseSound {
        let normalizedKeywords = keywords.map { $0.lowercased() }
        guard !normalizedKeywords.isEmpty else { return defaultFocusSound(from: options) }

        let candidates = options.filter { !$0.isNone }
        if let fullMatch = candidates.first(where: { sound in
            let text = "\(sound.title) \(sound.filename ?? "")".lowercased()
            return normalizedKeywords.allSatisfy { text.contains($0) }
        }) {
            return fullMatch
        }

        if let partialMatch = candidates.first(where: { sound in
            let text = "\(sound.title) \(sound.filename ?? "")".lowercased()
            return normalizedKeywords.contains { text.contains($0) }
        }) {
            return partialMatch
        }

        return defaultFocusSound(from: options)
    }

    static func url(for sound: NoiseSound) -> URL? {
        guard let filename = sound.filename else { return nil }

        let candidates = [
            Bundle.main.resourceURL?
                .appendingPathComponent("Sounds", isDirectory: true)
                .appendingPathComponent("Pomodoro", isDirectory: true)
                .appendingPathComponent(filename),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent("Noise", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Sounds", isDirectory: true)
                .appendingPathComponent("Pomodoro", isDirectory: true)
                .appendingPathComponent(filename)
        ].compactMap { $0 }

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func displayName(for filename: String) -> String {
        URL(fileURLWithPath: filename)
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bundledSounds() -> [NoiseSound] {
        let roots = [
            Bundle.main.resourceURL?
                .appendingPathComponent("Sounds", isDirectory: true)
                .appendingPathComponent("Pomodoro", isDirectory: true),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent("Noise", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Sounds", isDirectory: true)
                .appendingPathComponent("Pomodoro", isDirectory: true)
        ].compactMap { $0 }

        var found: [String: NoiseSound] = [:]
        for root in roots {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for url in entries {
                let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
                guard isRegular, supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
                let filename = url.lastPathComponent
                found[filename] = NoiseSound(
                    id: filename,
                    title: displayName(for: filename),
                    filename: filename
                )
            }
        }

        return found.values.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private static func defaultFocusSound(from options: [NoiseSound]) -> NoiseSound {
        let preferred = ["ocean", "rain", "river", "wind", "mountain", "woods", "atmosphere"]
        for keyword in preferred {
            if let sound = options.first(where: { !$0.isNone && $0.title.lowercased().contains(keyword) }) {
                return sound
            }
        }
        return options.first(where: { !$0.isNone }) ?? .none
    }
}
