import SwiftUI

struct NoiseSettingsView: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        Form {
            Section {
                Stepper(value: Binding(
                    get: { store.settings.focusMinutes },
                    set: { store.setFocusMinutes($0) }
                ), in: 1...180) { settingValue("专注", value: "\(store.settings.focusMinutes) 分钟") }
                .accessibilityLabel("专注时长")
                .accessibilityValue("\(store.settings.focusMinutes) 分钟")

                Stepper(value: Binding(
                    get: { store.settings.shortBreakMinutes },
                    set: { store.setShortBreakMinutes($0) }
                ), in: 1...60) { settingValue("短休息", value: "\(store.settings.shortBreakMinutes) 分钟") }
                .accessibilityLabel("短休息时长")
                .accessibilityValue("\(store.settings.shortBreakMinutes) 分钟")

                Stepper(value: Binding(
                    get: { store.settings.longBreakMinutes },
                    set: { store.setLongBreakMinutes($0) }
                ), in: 1...90) { settingValue("长休息", value: "\(store.settings.longBreakMinutes) 分钟") }
                .accessibilityLabel("长休息时长")
                .accessibilityValue("\(store.settings.longBreakMinutes) 分钟")

                Stepper(value: Binding(
                    get: { store.settings.roundsUntilLongBreak },
                    set: { store.setRoundsUntilLongBreak($0) }
                ), in: 2...12) { settingValue("长休息间隔", value: "\(store.settings.roundsUntilLongBreak) 轮") }
                .accessibilityLabel("长休息间隔")
                .accessibilityValue("\(store.settings.roundsUntilLongBreak) 轮")
                .disabled(store.state != .idle)
            } header: {
                Text("计时节奏")
            } footer: {
                Text("计时中修改时长，将在下一轮生效。长休息间隔请在本轮结束后调整。")
                    .foregroundStyle(NoisePalette.secondary)
            }

            Section("声音过渡") {
                HStack {
                    Text("淡入")
                    Slider(value: Binding(
                        get: { store.settings.fadeInSeconds },
                        set: { store.setFadeInSeconds($0) }
                    ), in: 0...8, step: 0.2)
                    .accessibilityLabel("声音淡入时长")
                    Text(String(format: "%.1f 秒", store.settings.fadeInSeconds))
                        .monospacedDigit().frame(width: 48, alignment: .trailing)
                }
                HStack {
                    Text("淡出")
                    Slider(value: Binding(
                        get: { store.settings.fadeOutSeconds },
                        set: { store.setFadeOutSeconds($0) }
                    ), in: 0...8, step: 0.2)
                    .accessibilityLabel("声音淡出时长")
                    Text(String(format: "%.1f 秒", store.settings.fadeOutSeconds))
                        .monospacedDigit().frame(width: 48, alignment: .trailing)
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
        .scrollContentBackground(.hidden)
        .padding(16)
        .frame(width: 500, height: 600)
        .foregroundStyle(NoisePalette.text)
        .background(NoisePalette.background)
        .tint(NoisePalette.primary)
    }

    private func settingValue(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(NoisePalette.secondary)
        }
    }
}
