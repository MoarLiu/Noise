import SwiftUI

struct NoiseSidebarView: View {
    @ObservedObject var store: NoiseStore
    @Binding var selection: NoiseWorkspaceSection

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(spacing: 5) {
                ForEach(NoiseWorkspaceSection.allCases) { section in
                    Button { selection = section } label: {
                        Label(section.title, systemImage: section.systemImage)
                            .font(.system(size: 13, weight: selection == section ? .medium : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(selection == section ? NoisePalette.selection : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == section ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("最近专注")
                    .font(.caption)
                    .foregroundStyle(NoisePalette.secondary)

                if store.recentTaskTitles.isEmpty {
                    Text("完成一轮后，任务会出现在这里。")
                        .font(.caption)
                        .foregroundStyle(NoisePalette.secondary)
                } else {
                    ForEach(Array(store.recentTaskTitles.prefix(5)), id: \.self) { title in
                        Button {
                            store.useTaskTitle(title)
                            selection = .focus
                        } label: {
                            Label(title, systemImage: "arrow.turn.down.right")
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("填入任务：\(title)")
                        .disabled(store.state != .idle)
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("今天，已经专注").font(.caption)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(NoiseFormatters.minutes(store.todayFocusSeconds))")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(NoisePalette.text)
                    Text("分钟").font(.caption)
                }
                Text("完成 \(store.todayRecords.count) 轮 · 按自己的节奏")
                    .font(.system(size: 11))
            }
            .foregroundStyle(NoisePalette.secondary)
            .padding(12)
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(NoisePalette.sidebar)
    }
}
