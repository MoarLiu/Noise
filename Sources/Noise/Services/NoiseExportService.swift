import AppKit
import Foundation

enum NoiseExportService {
    static func exportCSV(records: [NoiseFocusRecord]) throws -> NoiseExportSummary? {
        let panel = NSSavePanel()
        panel.title = "导出专注记录 CSV"
        panel.nameFieldStringValue = defaultFilename(extension: "csv")
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try csvString(records: records).write(to: url, atomically: true, encoding: .utf8)
        return NoiseExportSummary(message: "已导出 CSV", url: url)
    }

    static func exportMarkdown(records: [NoiseFocusRecord]) throws -> NoiseExportSummary? {
        let panel = NSSavePanel()
        panel.title = "导出专注复盘 Markdown"
        panel.nameFieldStringValue = defaultFilename(extension: "md")
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try markdownString(records: records).write(to: url, atomically: true, encoding: .utf8)
        return NoiseExportSummary(message: "已导出 Markdown", url: url)
    }

    static func csvString(records: [NoiseFocusRecord]) -> String {
        var rows = ["Task,Started At,Completed At,Minutes,Seconds"]
        for record in records.sorted(by: { $0.completedAt < $1.completedAt }) {
            rows.append([
                escapeCSV(record.displayTaskTitle),
                escapeCSV(NoiseFormatters.iso8601.string(from: record.startedAt)),
                escapeCSV(NoiseFormatters.iso8601.string(from: record.completedAt)),
                "\(record.roundedMinutes)",
                "\(record.durationSeconds)"
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    static func markdownString(records: [NoiseFocusRecord]) -> String {
        let sorted = records.sorted { $0.completedAt > $1.completedAt }
        let totalSeconds = sorted.reduce(0) { $0 + max(0, $1.durationSeconds) }
        let today = sorted.filter { Calendar.current.isDateInToday($0.completedAt) }

        var lines: [String] = []
        lines.append("# Noise 专注复盘")
        lines.append("")
        lines.append("- 导出时间：\(NoiseFormatters.shortDateTime.string(from: Date()))")
        lines.append("- 总轮次：\(sorted.count)")
        lines.append("- 总时长：\(NoiseFormatters.minutes(totalSeconds)) 分钟")
        lines.append("- 今日轮次：\(today.count)")
        lines.append("")

        if sorted.isEmpty {
            lines.append("暂无专注记录。")
        } else {
            lines.append("## 记录")
            lines.append("")
            for record in sorted {
                let completedAt = NoiseFormatters.shortDateTime.string(from: record.completedAt)
                lines.append("- \(completedAt) · \(record.displayTaskTitle) · \(record.roundedMinutes) 分钟")
            }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func defaultFilename(extension ext: String) -> String {
        "noise-focus-\(NoiseFormatters.filenameDate.string(from: Date())).\(ext)"
    }

    private static func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
