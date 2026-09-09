import SwiftUI

struct NoiseTimerWorkspaceView: View {
    @ObservedObject var store: NoiseStore
    var sidebarsVisible: Bool
    var toggleSidebars: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            header

            Spacer(minLength: 10)

            NoiseTimerRingView(store: store)

            taskField
                .frame(maxWidth: 420)

            NoiseSessionControlsView(store: store)

            if let completion = store.lastCompletion {
                NoiseCompletionBanner(store: store, completion: completion)
                    .frame(maxWidth: 520)
            }

            Spacer(minLength: 10)
        }
        .padding(30)
        .tint(NoisePalette.accent(for: store.mode))
    }

    private var header: some View {
        HStack {
            Label(store.mode.title, systemImage: store.mode.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(NoisePalette.accent(for: store.mode))

            Spacer()

            Text("第 \(store.nextFocusRoundNumber) / \(store.settings.roundsUntilLongBreak) 轮")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .opacity(store.mode == .focus ? 1 : 0)

            if store.state == .running {
                Button {
                    toggleSidebars()
                } label: {
                    Label(sidebarsVisible ? "隐藏面板" : "显示面板", systemImage: sidebarsVisible ? "sidebar.right" : "sidebar.leading")
                }
                .labelStyle(.iconOnly)
                .help(sidebarsVisible ? "隐藏面板" : "显示面板")
                .buttonStyle(.borderless)
            }
        }
    }

    private var taskField: some View {
        TextField("这轮要完成什么？", text: Binding(
            get: { store.taskTitle },
            set: { store.setTaskTitle($0) }
        ))
        .textFieldStyle(.roundedBorder)
    }
}

struct NoiseTimerRingView: View {
    @ObservedObject var store: NoiseStore
    @State private var displayedProgress = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 24)

            Circle()
                .trim(from: 0, to: displayedProgress)
                .stroke(
                    NoisePalette.accent(for: store.mode),
                    style: StrokeStyle(lineWidth: 24, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 10) {
                Text(NoiseFormatters.clock(store.remainingSeconds))
                    .font(.system(size: 74, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Text(store.state.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(store.activeSound.title)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(width: 240)
            }
        }
        .frame(width: 340, height: 340)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("剩余 \(NoiseFormatters.clock(store.remainingSeconds))，\(store.mode.title)，\(store.state.title)")
        .onAppear {
            displayedProgress = store.progress
        }
        .onChange(of: store.progress) { newValue in
            if newValue < displayedProgress {
                displayedProgress = newValue
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedProgress = newValue
                }
            }
        }
        .onChange(of: store.mode) { _ in
            displayedProgress = store.progress
        }
    }
}

struct NoiseSessionControlsView: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        HStack(spacing: 12) {
            switch store.state {
            case .idle:
                Button {
                    store.startBreak()
                } label: {
                    Label("休息", systemImage: "cup.and.saucer")
                }

                Button {
                    store.startFocus()
                } label: {
                    Label("开始专注", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])

            case .running:
                Button {
                    store.pause()
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])

                Button {
                    store.stop()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .keyboardShortcut(.escape, modifiers: [])

            case .paused:
                Button {
                    store.stop()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .keyboardShortcut(.escape, modifiers: [])

                Button {
                    store.resume()
                } label: {
                    Label("继续", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
            }
        }
        .controlSize(.large)
    }
}

struct NoiseCompletionBanner: View {
    @ObservedObject var store: NoiseStore
    let completion: NoiseCompletion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(NoisePalette.accent(for: completion.mode))

            VStack(alignment: .leading, spacing: 2) {
                Text(completion.title)
                    .font(.headline)
                Text(NoiseFormatters.shortDateTime.string(from: completion.completedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if completion.mode == .focus {
                Button("休息一下") {
                    store.startBreak()
                }
                Button("再来一轮") {
                    store.startFocus()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("开始专注") {
                    store.startFocus()
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                store.dismissCompletion()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .noisePanel()
    }
}
