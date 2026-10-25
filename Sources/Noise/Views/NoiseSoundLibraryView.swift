import SwiftUI

struct NoiseSoundPicker: View {
    var title: String
    @Binding var selection: NoiseSound

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(NoiseSoundLibrary.groupedOptions, id: \.category) { group in
                Section(group.category.title) {
                    ForEach(group.sounds) { sound in
                        Text(sound.title).tag(sound)
                    }
                }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .accessibilityLabel(title)
    }
}

struct NoiseSoundLibraryView: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("给专注一点背景声")
                        .font(.system(size: 25, weight: .medium))
                    Text("选一段喜欢的声音，音量保持你的设置。")
                        .font(.callout)
                        .foregroundStyle(NoisePalette.secondary)
                }

                HStack(alignment: .top, spacing: 14) {
                    soundSelection(title: "专注声音", isFocus: true)
                    soundSelection(title: "休息声音", isFocus: false)
                }

                HStack {
                    Text("音量").font(.callout)
                    Spacer()
                    NoiseVolumeControl(store: store)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("声景组合").font(.headline)
                    Text("同时设置专注与休息声音，保留当前音量和静音状态。")
                        .font(.caption)
                        .foregroundStyle(NoisePalette.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(NoiseSoundscapePreset.allCases) { preset in
                        Button { store.applySoundscape(preset) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: NoiseSoundLibrary.bestMatch(keywords: preset.focusKeywords).category.systemImage)
                                    .font(.system(size: 20))
                                    .foregroundStyle(NoisePalette.primary)
                                Text(preset.title).font(.system(size: 14, weight: .medium))
                                Text(preset.detail)
                                    .font(.caption)
                                    .foregroundStyle(NoisePalette.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
                            .padding(16)
                            .noisePanel()
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 680)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func soundSelection(title: String, isFocus: Bool) -> some View {
        let sound = isFocus ? store.focusSound : store.breakSound
        let isPreviewing = store.previewingSoundID == sound.id
        return VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: isFocus ? "headphones" : "cup.and.saucer")
                .font(.system(size: 13, weight: .medium))
            NoiseSoundPicker(title: title, selection: Binding(
                get: { isFocus ? store.focusSound : store.breakSound },
                set: { isFocus ? store.setFocusSound($0) : store.setBreakSound($0) }
            ))
            .frame(maxWidth: .infinity)

            Button {
                if isPreviewing {
                    store.stopPreview()
                } else if isFocus {
                    store.previewFocusSound()
                } else {
                    store.previewBreakSound()
                }
            } label: {
                Label(isPreviewing ? "停止试听" : "试听 8 秒", systemImage: isPreviewing ? "stop.circle" : "play.circle")
                    .font(.caption)
            }
            .disabled(store.state == .running || sound.isNone)
            .help(store.state == .running ? "计时中，所选声音会直接播放" : "试听所选声音")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .noisePanel()
    }
}
