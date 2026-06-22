import AppKit
import SwiftUI

@main
struct NoiseApp: App {
    @NSApplicationDelegateAdaptor(NoiseAppDelegate.self) private var appDelegate
    @StateObject private var store = NoiseStore()

    var body: some Scene {
        WindowGroup("Noise", id: "main") {
            ContentView(store: store)
        }
        .defaultSize(width: 1260, height: 860)
        .commands {
            CommandMenu("Noise") {
                Button("开始专注") {
                    store.startFocus()
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(store.state == .running)

                Button(store.state == .paused ? "继续" : "暂停") {
                    store.state == .paused ? store.resume() : store.pause()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(store.state == .idle)

                Button("停止") {
                    store.stop()
                }
                .keyboardShortcut(".", modifiers: [.command, .option])
                .disabled(store.state == .idle)

                Divider()

                Button("导出 CSV") {
                    store.exportRecordsCSV()
                }
                .disabled(store.records.isEmpty)

                Button("导出 Markdown") {
                    store.exportRecordsMarkdown()
                }
                .disabled(store.records.isEmpty)
            }
        }

        MenuBarExtra(store.menuBarTitle ?? "Noise", systemImage: store.menuBarSystemImage) {
            NoiseMenuBarView(store: store)
        }

        Settings {
            NoiseSettingsView(store: store)
        }
    }
}

final class NoiseAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
