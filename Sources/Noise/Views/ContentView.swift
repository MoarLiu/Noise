import SwiftUI

struct ContentView: View {
    @ObservedObject var store: NoiseStore
    @SceneStorage("Noise.sidebarsVisible") private var sidebarsVisible = true

    private var showsSidebars: Bool {
        store.state == .running ? sidebarsVisible : true
    }

    var body: some View {
        HStack(spacing: 0) {
            if showsSidebars {
                NoiseSidebarView(store: store)
                    .frame(width: 230)

                Divider()
            }

            NoiseTimerWorkspaceView(
                store: store,
                sidebarsVisible: showsSidebars,
                toggleSidebars: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sidebarsVisible.toggle()
                    }
                }
            )
                .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)

            if showsSidebars {
                Divider()

                NoiseInspectorView(store: store)
                    .frame(width: 340)
            }
        }
        .frame(minWidth: showsSidebars ? 1080 : 560, minHeight: 860)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: store.state) { state in
            if state == .running {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sidebarsVisible = false
                }
            }
        }
    }
}
