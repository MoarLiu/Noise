import SwiftUI

struct NoiseSidebarView: View {
    @ObservedObject var store: NoiseStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Noise")
                    .font(.system(size: 24, weight: .semibold))
                Text("白噪音番茄闹钟")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("预设")
                    .font(.headline)

                ForEach(NoisePreset.allCases) { preset in
                    Button {
                        store.applyPreset(preset)
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                                .frame(width: 18)
                            Text(preset.title)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("最近任务")
                    .font(.headline)

                if store.recentTaskTitles.isEmpty {
                    Text("暂无记录")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.recentTaskTitles, id: \.self) { title in
                        Button {
                            store.useTaskTitle(title)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .frame(width: 18)
                                Text(title)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                }
            }

            Spacer()
        }
        .padding(22)
        .background(.bar)
    }
}
