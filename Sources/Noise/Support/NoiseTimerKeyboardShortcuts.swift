import AppKit
import SwiftUI

/// Bare timer shortcuts apply only to this workspace's key window, outside text editing.
struct NoiseTimerKeyboardShortcuts: NSViewRepresentable {
    var store: NoiseStore
    var enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.enabled = enabled
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        weak var view: NSView?
        var enabled = false
        private let store: NoiseStore
        private var monitor: Any?

        init(store: NoiseStore) { self.store = store }
        deinit { removeMonitor() }

        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.enabled,
                      let window = self.view?.window, window.isKeyWindow,
                      event.window === window,
                      window.attachedSheet == nil,
                      !event.isARepeat,
                      event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                      !(window.firstResponder is NSTextView),
                      !(window.firstResponder is NSControl) else { return event }

                if event.keyCode == 49, self.store.state != .idle {
                    self.store.state == .running ? self.store.pause() : self.store.resume()
                    return nil
                }
                if [36, 76].contains(event.keyCode), self.store.state == .idle {
                    switch self.store.mode {
                    case .focus: self.store.startFocus()
                    case .shortBreak: self.store.startShortBreak()
                    case .longBreak: self.store.startLongBreak()
                    }
                    return nil
                }
                return event
            }
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
