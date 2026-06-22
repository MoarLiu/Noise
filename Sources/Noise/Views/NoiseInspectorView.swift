import SwiftUI

struct NoiseInspectorView: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let persistenceError = store.persistenceError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(persistenceError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .noisePanel()
                }
                NoiseSoundSection(store: store)
                Divider()
                NoisePlanSection(store: store)
                Divider()
                NoiseStatsSection(store: store)
            }
            .padding(22)
        }
        .tint(NoisePalette.accent(for: store.mode))
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct NoiseSoundSection: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("声音", systemImage: "speaker.wave.2")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(NoiseSoundscapePreset.allCases) { preset in
                    Button {
                        store.applySoundscape(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.title)
                                .font(.callout.weight(.semibold))
                            Text(preset.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .padding(8)
                    .noisePanel()
                }
            }

            Picker("专注", selection: Binding(
                get: { store.focusSound },
                set: { store.setFocusSound($0) }
            )) {
                ForEach(NoiseSoundLibrary.groupedOptions, id: \.category) { group in
                    Section(group.category.title) {
                        ForEach(group.sounds) { sound in
                            Label(sound.title, systemImage: sound.category.systemImage).tag(sound)
                        }
                    }
                }
            }

            Picker("休息", selection: Binding(
                get: { store.breakSound },
                set: { store.setBreakSound($0) }
            )) {
                ForEach(NoiseSoundLibrary.groupedOptions, id: \.category) { group in
                    Section(group.category.title) {
                        ForEach(group.sounds) { sound in
                            Label(sound.title, systemImage: sound.category.systemImage).tag(sound)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    store.previewFocusSound()
                } label: {
                    Label("试听专注", systemImage: "play.circle")
                }
                .disabled(store.state == .running || store.focusSound.isNone)

                Button {
                    store.previewBreakSound()
                } label: {
                    Label("试听休息", systemImage: "play.circle")
                }
                .disabled(store.state == .running || store.breakSound.isNone)
            }

            HStack {
                Text("音量")
                Slider(value: Binding(
                    get: { store.settings.volume },
                    set: { store.setVolume($0) }
                ), in: 0...1)
                Text("\(Int((store.settings.volume * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

struct NoisePlanSection: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("循环", systemImage: "repeat")
                .font(.headline)

            Stepper(value: Binding(
                get: { store.settings.focusMinutes },
                set: { store.setFocusMinutes($0) }
            ), in: 1...180) {
                valueRow("专注", value: "\(store.settings.focusMinutes) 分钟")
            }
            .disabled(store.state == .running)

            Stepper(value: Binding(
                get: { store.settings.shortBreakMinutes },
                set: { store.setShortBreakMinutes($0) }
            ), in: 1...60) {
                valueRow("短休息", value: "\(store.settings.shortBreakMinutes) 分钟")
            }
            .disabled(store.state == .running)

            Stepper(value: Binding(
                get: { store.settings.longBreakMinutes },
                set: { store.setLongBreakMinutes($0) }
            ), in: 1...90) {
                valueRow("长休息", value: "\(store.settings.longBreakMinutes) 分钟")
            }
            .disabled(store.state == .running)

            Stepper(value: Binding(
                get: { store.settings.roundsUntilLongBreak },
                set: { store.setRoundsUntilLongBreak($0) }
            ), in: 2...12) {
                valueRow("长休息间隔", value: "\(store.settings.roundsUntilLongBreak) 轮")
            }

            Toggle("自动开始下一轮", isOn: Binding(
                get: { store.settings.autoStartNextRound },
                set: { store.setAutoStartNextRound($0) }
            ))

            Toggle("菜单栏倒计时", isOn: Binding(
                get: { store.settings.countdownInMenuBar },
                set: { store.setCountdownInMenuBar($0) }
            ))

            Toggle("完成通知", isOn: Binding(
                get: { store.settings.notificationsEnabled },
                set: { store.setNotificationsEnabled($0) }
            ))
        }
    }

    private func valueRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

struct NoiseStatsSection: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("统计", systemImage: "chart.bar")
                .font(.headline)

            HStack(spacing: 10) {
                metric(title: "今日", value: "\(store.todayRecords.count)", detail: "\(NoiseFormatters.minutes(store.todayFocusSeconds)) 分钟")
                metric(title: "近 7 天", value: "\(store.sevenDayRecords.count)", detail: "\(NoiseFormatters.minutes(store.sevenDayFocusSeconds)) 分钟")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("高频任务")
                    .font(.subheadline.weight(.semibold))

                if store.topTasks.isEmpty {
                    Text("暂无记录")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.topTasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(task.title)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(task.rounds) 轮")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.callout)

                            ProgressView(value: Double(task.totalSeconds), total: Double(maxTopTaskSeconds))
                                .tint(NoisePalette.focus)
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("最近记录")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("CSV") {
                        store.exportRecordsCSV()
                    }
                    .disabled(store.records.isEmpty)
                    Button("Markdown") {
                        store.exportRecordsMarkdown()
                    }
                    .disabled(store.records.isEmpty)
                }

                if store.records.isEmpty {
                    Text("暂无记录")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(store.records.prefix(5))) { record in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(NoisePalette.focus)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.displayTaskTitle)
                                    .lineLimit(1)
                                Text(NoiseFormatters.shortDateTime.string(from: record.completedAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(record.roundedMinutes) 分")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let exportSummary = store.exportSummary {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("\(exportSummary.message)：\(exportSummary.url.lastPathComponent)")
                            .lineLimit(1)
                        Spacer()
                        Button {
                            store.dismissExportStatus()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let exportErrorMessage = store.exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var maxTopTaskSeconds: Int {
        max(store.topTasks.map(\.totalSeconds).max() ?? 1, 1)
    }

    private func metric(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .noisePanel()
    }
}
