import SwiftUI

enum NoiseWorkspaceSection: String, CaseIterable, Identifiable {
    case focus, sounds, records

    var id: String { rawValue }
    var title: String {
        switch self {
        case .focus: return "专注"
        case .sounds: return "声景"
        case .records: return "记录"
        }
    }
    var systemImage: String {
        switch self {
        case .focus: return "timer"
        case .sounds: return "headphones"
        case .records: return "chart.bar.xaxis"
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: NoiseStore
    @SceneStorage("Noise.workspaceExpanded") private var workspaceExpanded = false
    @SceneStorage("Noise.workspaceSection") private var sectionName = NoiseWorkspaceSection.focus.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var section: Binding<NoiseWorkspaceSection> {
        Binding(
            get: { NoiseWorkspaceSection(rawValue: sectionName) ?? .focus },
            set: { sectionName = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let message = store.persistenceError {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(NoisePalette.focus)
                    .textSelection(.enabled)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoisePalette.surface)
            }

            HStack(spacing: 0) {
                if workspaceExpanded {
                    NoiseSidebarView(store: store, selection: section)
                        .frame(width: 184)
                    Rectangle().fill(NoisePalette.separator).frame(width: 1)
                }

                Group {
                    switch section.wrappedValue {
                    case .focus:
                        NoiseTimerWorkspaceView(store: store)
                    case .sounds:
                        NoiseSoundLibraryView(store: store)
                    case .records:
                        NoiseRecordsView(store: store) { section.wrappedValue = .focus }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 680, minHeight: 640)
        .foregroundStyle(NoisePalette.text)
        .background(NoisePalette.background)
        .tint(NoisePalette.primary)
    }

    private var header: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundStyle(NoisePalette.primary)
                Text("Noise").font(.system(size: 18, weight: .semibold))
            }

            Spacer(minLength: 12)

            if !workspaceExpanded {
                Picker("工作区", selection: section) {
                    ForEach(NoiseWorkspaceSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 196)
                .accessibilityLabel("工作区")
            }

            Spacer(minLength: 12)

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    workspaceExpanded.toggle()
                }
            } label: {
                Label(workspaceExpanded ? "沉浸" : "工作台", systemImage: workspaceExpanded ? "arrow.down.right.and.arrow.up.left" : "sidebar.left")
                    .font(.system(size: 11))
                    .foregroundStyle(NoisePalette.secondary)
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(workspaceExpanded ? "收起工作台，保持专注" : "展开工作台与最近任务")
            .accessibilityValue(workspaceExpanded ? "工作台已展开" : "沉浸视图")

            NoiseSettingsButton()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}
