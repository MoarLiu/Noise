import Foundation
import UserNotifications

protocol NoiseNotificationing {
    func requestAuthorizationIfNeeded()
    func deliver(completion: NoiseCompletion, nextMode: NoiseTimerMode, autoStartNextRound: Bool)
}

final class NoiseNotificationService: NSObject, NoiseNotificationing, UNUserNotificationCenterDelegate {
    private static let notificationTaskTitleLimit = 20

    private let center = UNUserNotificationCenter.current()
    private var requestedAuthorization = false

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        guard !requestedAuthorization else { return }
        requestedAuthorization = true
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("Noise notification authorization failed: \(error.localizedDescription)")
            } else {
                NSLog("Noise notification authorization granted: \(granted)")
            }
        }
    }

    func deliver(completion: NoiseCompletion, nextMode: NoiseTimerMode, autoStartNextRound: Bool) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.addNotification(completion: completion, nextMode: nextMode, autoStartNextRound: autoStartNextRound)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    self.requestedAuthorization = true
                    if let error {
                        NSLog("Noise notification authorization failed: \(error.localizedDescription)")
                    }
                    guard granted else { return }
                    self.addNotification(completion: completion, nextMode: nextMode, autoStartNextRound: autoStartNextRound)
                }
            case .denied:
                return
            @unknown default:
                return
            }
        }
    }

    private func addNotification(completion: NoiseCompletion, nextMode: NoiseTimerMode, autoStartNextRound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = completion.title
        content.body = body(for: completion, nextMode: nextMode, autoStartNextRound: autoStartNextRound)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "noise.session.\(completion.id.uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                NSLog("Noise notification delivery failed: \(error.localizedDescription)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func body(for completion: NoiseCompletion, nextMode: NoiseTimerMode, autoStartNextRound: Bool) -> String {
        switch completion.mode {
        case .focus:
            let minutes = NoiseFormatters.minutes(completion.durationSeconds)
            let title = Self.notificationTaskTitle(completion.taskTitle)
            let task = title.isEmpty ? "本轮专注" : "「\(title)」"
            let next = autoStartNextRound ? "已自动进入\(nextMode.title)。" : "可以休息一下。"
            return "\(task)完成 \(minutes) 分钟，\(next)"
        case .shortBreak, .longBreak:
            return autoStartNextRound ? "已自动进入下一轮专注。" : "可以开始下一轮专注。"
        }
    }

    private static func notificationTaskTitle(_ value: String) -> String {
        let title = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count > notificationTaskTitleLimit else { return title }
        return String(title.prefix(notificationTaskTitleLimit)) + "..."
    }
}
