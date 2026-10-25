import SwiftUI

struct NoiseRecordsView: View {
    @ObservedObject var store: NoiseStore
    var showFocus: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("每一段专注，都算数")
                            .font(.system(size: 25, weight: .medium))
                        Text("按自己的节奏，回看已经完成的事。")
                            .font(.callout)
                            .foregroundStyle(NoisePalette.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("导出 CSV…") { store.exportRecordsCSV() }
                        Button("导出 Markdown…") { store.exportRecordsMarkdown() }
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .fixedSize()
                    .disabled(store.records.isEmpty)
                }

                HStack(spacing: 30) {
                    metric("今日专注", seconds: store.todayFocusSeconds, rounds: store.todayRecords.count)
                    metric("近 7 天", seconds: store.sevenDayFocusSeconds, rounds: store.sevenDayRecords.count)
                }

                if let summary = store.exportSummary {
                    HStack {
                        Label("\(summary.message)：\(summary.url.lastPathComponent)", systemImage: "checkmark.circle")
                            .lineLimit(2)
                        Spacer()
                        Button { store.dismissExportStatus() } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain)
                            .accessibilityLabel("关闭导出提示")
                    }
                    .font(.caption)
                    .foregroundStyle(NoisePalette.secondary)
                }
                if let message = store.exportErrorMessage {
                    Text(message).font(.callout).foregroundStyle(.red)
                }

                if store.records.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "leaf")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(NoisePalette.primary)
                        Text("从一轮专注开始").font(.headline)
                        Text("完成第一轮后，时间和任务会记录在这里。")
                            .font(.callout)
                            .foregroundStyle(NoisePalette.secondary)
                        Button("去专注", action: showFocus)
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 52)
                } else {
                    if !store.topTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("近 7 天高频任务").font(.headline)
                            ForEach(store.topTasks) { task in
                                HStack {
                                    Text(task.title).lineLimit(1).help(task.title)
                                    Spacer()
                                    Text("\(task.rounds) 轮 · \(task.roundedMinutes) 分钟")
                                        .foregroundStyle(NoisePalette.secondary)
                                }
                                .font(.callout)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("专注记录").font(.headline)
                        LazyVStack(spacing: 0) {
                            ForEach(store.records) { record in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(NoisePalette.primary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.displayTaskTitle).lineLimit(2)
                                        Text(NoiseFormatters.shortDateTime.string(from: record.completedAt))
                                            .font(.caption)
                                            .foregroundStyle(NoisePalette.secondary)
                                    }
                                    Spacer(minLength: 12)
                                    Text("\(record.roundedMinutes) 分钟")
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(NoisePalette.secondary)
                                }
                                .padding(.vertical, 14)
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 680)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func metric(_ title: String, seconds: Int, rounds: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(NoisePalette.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(NoiseFormatters.minutes(seconds))")
                    .font(.system(size: 32, weight: .light))
                Text("分钟").font(.callout).foregroundStyle(NoisePalette.secondary)
            }
            Text("完成 \(rounds) 轮").font(.caption).foregroundStyle(NoisePalette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
