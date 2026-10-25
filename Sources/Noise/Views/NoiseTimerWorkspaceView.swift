import SwiftUI

struct NoiseTimerWorkspaceView: View {
    @ObservedObject var store: NoiseStore
    @FocusState private var editingTask: Bool
    @State private var confirmingEnd = false
    @State private var endingSessionID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            presetRow

            Spacer(minLength: 8)

            taskField

            Picker("计时模式", selection: Binding(
                get: { store.mode },
                set: { store.selectMode($0) }
            )) {
                ForEach(NoiseTimerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 260)
            .disabled(store.state != .idle)
            .padding(.top, 18)

            Text(NoiseFormatters.clock(store.remainingSeconds))
                .font(.system(size: 108, weight: .light))
                .monospacedDigit()
                .tracking(-5)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
                .frame(height: 122)
                .padding(.top, 12)
                .accessibilityLabel("剩余时间")
                .accessibilityValue(NoiseFormatters.clock(store.remainingSeconds))

            ProgressView(value: store.progress)
                .progressViewStyle(NoiseTimerProgressStyle(color: NoisePalette.accent(for: store.mode)))
                .frame(width: 220)
                .accessibilityLabel("本轮已完成进度")

            Text(statusText)
                .font(.system(size: 12))
                .foregroundStyle(NoisePalette.secondary)
                .lineLimit(1)
                .frame(height: 20)
                .padding(.top, 10)

            sessionControls
                .padding(.top, 14)

            Text(editingTask ? "Return 完成输入" : store.state == .idle ? "Return 开始" : store.state == .running ? "空格 暂停" : "空格 继续")
                .font(.system(size: 10))
                .foregroundStyle(NoisePalette.secondary)
                .padding(.top, 6)
                .accessibilityHidden(true)

            Text(nextStepText)
                .font(.system(size: 11))
                .foregroundStyle(NoisePalette.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 32)
                .padding(.top, 4)

            Spacer(minLength: 12)

            NoiseSoundDock(store: store)
                .frame(maxWidth: 480)

            HStack(spacing: 12) {
                Text("今日专注 \(NoiseFormatters.minutes(store.todayFocusSeconds)) 分钟 · 完成 \(store.todayRecords.count) 轮")
                Spacer()
                Text("本地优先")
            }
            .font(.system(size: 11))
            .foregroundStyle(NoisePalette.secondary)
            .padding(.top, 18)
        }
        .padding(.horizontal, 28)
        .padding(.top, 6)
        .padding(.bottom, 20)
        .background {
            NoiseTimerKeyboardShortcuts(store: store, enabled: !editingTask && !confirmingEnd)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .confirmationDialog("要结束这一轮吗？", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("结束本轮", role: .destructive) {
                if let endingSessionID { store.stopSession(ifMatching: endingSessionID) }
                endingSessionID = nil
            }
            Button("回到计时", role: .cancel) { endingSessionID = nil }
        } message: {
            Text(store.mode == .focus ? "未完成的这一轮不会计入已完成的番茄。" : "结束休息后，将回到专注准备界面。")
        }
        .onReceive(store.$sessionID) { sessionID in
            if sessionID != endingSessionID {
                confirmingEnd = false
                endingSessionID = nil
            }
        }
    }

    private var presetRow: some View {
        HStack {
            Spacer()
            Menu {
                ForEach(NoisePreset.allCases) { preset in
                    Button(preset.displayTitle) { store.applyPreset(preset) }
                }
            } label: {
                Text(presetTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(NoisePalette.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(store.state != .idle)
            .accessibilityLabel("专注时长预设")
        }
        .frame(height: 24)
    }

    private var presetTitle: String {
        NoisePreset.allCases.first {
            $0.focusMinutes == store.settings.focusMinutes && $0.shortBreakMinutes == store.settings.shortBreakMinutes
        }?.displayTitle ?? "自定义 · \(store.settings.focusMinutes) / \(store.settings.shortBreakMinutes)"
    }

    private var taskField: some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Text(store.mode == .focus ? "把这一刻，留给一件事" : "下一轮专注，准备做什么？")
                    .font(.system(size: 11))
                    .foregroundStyle(NoisePalette.secondary)
                if !store.recentTaskTitles.isEmpty {
                    Menu {
                        ForEach(store.recentTaskTitles, id: \.self) { title in
                            Button(title) { store.useTaskTitle(title) }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("填入最近任务")
                    .accessibilityLabel("最近任务")
                    .disabled(store.state != .idle)
                }
            }

            TextField("写下一个小目标（可选）", text: Binding(
                get: { store.taskTitle },
                set: { store.setTaskTitle($0) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 20, weight: .medium))
            .multilineTextAlignment(.center)
            .focused($editingTask)
            .disabled(store.state != .idle)
            .accessibilityLabel("这一轮的任务，可选")
            .onSubmit { editingTask = false }
        }
        .frame(maxWidth: 420)
    }

    private var sessionControls: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 90, height: 42).accessibilityHidden(true)

            Button(action: performPrimaryAction) {
                Label(primaryTitle, systemImage: store.state == .running ? "pause.fill" : "play.fill")
            }
            .buttonStyle(NoisePrimaryButtonStyle())

            Group {
                if store.state != .idle {
                    Button("结束本轮…") {
                        endingSessionID = store.sessionID
                        confirmingEnd = endingSessionID != nil
                    }
                        .buttonStyle(.plain)
                        .foregroundStyle(NoisePalette.secondary)
                } else if store.lastCompletion?.mode == .focus {
                    Button("再专注一轮") { store.startFocus() }
                        .buttonStyle(.plain)
                        .foregroundStyle(NoisePalette.secondary)
                } else {
                    Color.clear.accessibilityHidden(true)
                }
            }
            .font(.system(size: 11))
            .frame(width: 90, height: 42)
        }
    }

    private var primaryTitle: String {
        switch store.state {
        case .running: return "暂停"
        case .paused: return "继续"
        case .idle:
            switch store.mode {
            case .focus: return "开始专注"
            case .shortBreak: return "休息 \(store.settings.shortBreakMinutes) 分钟"
            case .longBreak: return "长休息 \(store.settings.longBreakMinutes) 分钟"
            }
        }
    }

    private var statusText: String {
        switch store.state {
        case .running:
            return store.mode == .focus
                ? "正在专注 · 第 \(store.nextFocusRoundNumber) / \(store.settings.roundsUntilLongBreak) 轮"
                : "正在\(store.mode.title)"
        case .paused: return "已暂停 · 时间留在这里"
        case .idle:
            if let completion = store.lastCompletion {
                return completion.mode == .focus
                    ? "完成 \(NoiseFormatters.minutes(completion.durationSeconds)) 分钟专注 · 该休息一下了"
                    : completion.title
            }
            return "准备好了，就开始吧"
        }
    }

    private var nextStepText: String {
        let next: String
        if store.mode == .focus {
            let longBreak = store.nextFocusRoundNumber == store.settings.roundsUntilLongBreak
            let minutes = longBreak ? store.settings.longBreakMinutes : store.settings.shortBreakMinutes
            next = "第 \(store.nextFocusRoundNumber) / \(store.settings.roundsUntilLongBreak) 轮 · 接下来\(longBreak ? "长休息" : "休息") \(minutes) 分钟"
        } else {
            next = "\(store.mode.title)结束后 · 专注 \(store.settings.focusMinutes) 分钟"
        }
        return next + (store.settings.autoStartNextRound ? " · 自动开始" : "")
    }

    private func performPrimaryAction() {
        editingTask = false
        switch store.state {
        case .running: store.pause()
        case .paused: store.resume()
        case .idle:
            switch store.mode {
            case .focus: store.startFocus()
            case .shortBreak: store.startShortBreak()
            case .longBreak: store.startLongBreak()
            }
        }
    }
}

private struct NoiseTimerProgressStyle: ProgressViewStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(NoisePalette.separator)
                Capsule().fill(color)
                    .frame(width: geometry.size.width * min(max(configuration.fractionCompleted ?? 0, 0), 1))
            }
        }
        .frame(height: 3)
    }
}

struct NoiseSoundDock: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: store.activeSound.category.systemImage)
                .font(.system(size: 21))
                .foregroundStyle(NoisePalette.primary)
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.mode == .focus ? "专注声景" : "休息声景")
                    .font(.system(size: 10))
                    .foregroundStyle(NoisePalette.secondary)
                NoiseSoundPicker(
                    title: store.mode == .focus ? "专注声景" : "休息声景",
                    selection: Binding(
                        get: { store.activeSound },
                        set: { store.mode == .focus ? store.setFocusSound($0) : store.setBreakSound($0) }
                    )
                )
                .font(.system(size: 12))
                .frame(maxWidth: 185)
                .help(store.activeSound.title)
            }

            Spacer(minLength: 4)

            NoiseVolumeControl(store: store, sliderWidth: 86)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .noisePanel()
    }
}

struct NoiseVolumeControl: View {
    @ObservedObject var store: NoiseStore
    var sliderWidth: CGFloat = 140

    var body: some View {
        HStack(spacing: 8) {
            Button { store.setMuted(!store.settings.isMuted) } label: {
                Image(systemName: store.settings.isMuted || store.settings.volume == 0 ? "speaker.slash" : "speaker.wave.2")
                    .frame(width: 22, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(store.settings.isMuted ? "取消静音" : "静音")
            .accessibilityLabel(store.settings.isMuted ? "取消静音" : "静音")

            Slider(value: Binding(
                get: { store.settings.volume },
                set: { store.setVolume($0) }
            ), in: 0...1)
            .frame(width: sliderWidth)
            .accessibilityLabel("声景音量")

            Text(store.settings.isMuted ? "静音" : "\(Int((store.settings.volume * 100).rounded()))%")
                .font(.system(size: 11))
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
        .foregroundStyle(NoisePalette.secondary)
    }
}
