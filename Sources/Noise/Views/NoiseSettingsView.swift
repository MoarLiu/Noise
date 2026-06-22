import SwiftUI

struct NoiseSettingsView: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        Form {
            Section("计时") {
                Stepper(value: Binding(
                    get: { store.settings.focusMinutes },
                    set: { store.setFocusMinutes($0) }
                ), in: 1...180) {
                    Text("专注：\(store.settings.focusMinutes) 分钟")
                        .monospacedDigit()
                }

                Stepper(value: Binding(
                    get: { store.settings.shortBreakMinutes },
                    set: { store.setShortBreakMinutes($0) }
                ), in: 1...60) {
                    Text("短休息：\(store.settings.shortBreakMinutes) 分钟")
                        .monospacedDigit()
                }

                Stepper(value: Binding(
                    get: { store.settings.longBreakMinutes },
                    set: { store.setLongBreakMinutes($0) }
                ), in: 1...90) {
                    Text("长休息：\(store.settings.longBreakMinutes) 分钟")
                        .monospacedDigit()
                }

                Stepper(value: Binding(
                    get: { store.settings.roundsUntilLongBreak },
                    set: { store.setRoundsUntilLongBreak($0) }
                ), in: 2...12) {
                    Text("长休息间隔：\(store.settings.roundsUntilLongBreak) 轮")
                        .monospacedDigit()
                }
            }

            Section("声音") {
                Picker("专注声音", selection: Binding(
                    get: { store.focusSound },
                    set: { store.setFocusSound($0) }
                )) {
                    ForEach(store.soundOptions) { sound in
                        Text(sound.title).tag(sound)
                    }
                }

                Picker("休息声音", selection: Binding(
                    get: { store.breakSound },
                    set: { store.setBreakSound($0) }
                )) {
                    ForEach(store.soundOptions) { sound in
                        Text(sound.title).tag(sound)
                    }
                }

                Slider(value: Binding(
                    get: { store.settings.volume },
                    set: { store.setVolume($0) }
                ), in: 0...1) {
                    Text("音量")
                }

                Slider(value: Binding(
                    get: { store.settings.fadeInSeconds },
                    set: { store.setFadeInSeconds($0) }
                ), in: 0...8) {
                    Text("淡入")
                }

                Slider(value: Binding(
                    get: { store.settings.fadeOutSeconds },
                    set: { store.setFadeOutSeconds($0) }
                ), in: 0...8) {
                    Text("淡出")
                }
            }

            Section("行为") {
                Toggle("自动开始下一轮", isOn: Binding(
                    get: { store.settings.autoStartNextRound },
                    set: { store.setAutoStartNextRound($0) }
                ))

                Toggle("菜单栏倒计时", isOn: Binding(
                    get: { store.settings.countdownInMenuBar },
                    set: { store.setCountdownInMenuBar($0) }
                ))

                Toggle("完成时发送通知", isOn: Binding(
                    get: { store.settings.notificationsEnabled },
                    set: { store.setNotificationsEnabled($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460, height: 520)
    }
}
