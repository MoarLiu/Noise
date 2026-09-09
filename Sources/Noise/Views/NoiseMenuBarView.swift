import AppKit
import SwiftUI

struct NoiseMenuBarView: View {
    @ObservedObject var store: NoiseStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.menuBarTitle ?? "Noise")
                    .font(.headline)
                if store.state != .idle {
                    Text(Self.shortMenuText(menuDetail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button("打开 Noise") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            switch store.state {
            case .idle:
                Button("开始专注") {
                    store.startFocus()
                }
                Button("开始休息") {
                    store.startBreak()
                }
            case .running:
                Button("暂停") {
                    store.pause()
                }
                Button("停止") {
                    store.stop()
                }
            case .paused:
                Button("继续") {
                    store.resume()
                }
                Button("停止") {
                    store.stop()
                }
            }

            Divider()

            Toggle("自动下一轮", isOn: Binding(
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

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
        }
    }

    private var menuDetail: String {
        let title = store.taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = title.isEmpty ? "未命名专注" : title
        if store.mode == .focus {
            return "第 \(store.nextFocusRoundNumber)/\(store.settings.roundsUntilLongBreak) 轮 · \(task)"
        }
        return store.mode.title
    }

    private static func shortMenuText(_ value: String) -> String {
        guard value.count > 30 else { return value }
        return String(value.prefix(27)) + "..."
    }
}
