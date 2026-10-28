import SwiftUI

struct MacSettingsView: View {
    @AppStorage("themeMode") private var themeMode = 0
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink {
                    MacAppearanceSettingsView(themeMode: $themeMode)
                } label: {
                    Label("外观", systemImage: "paintbrush")
                }
                NavigationLink {
                    MacSyncSettingsView()
                } label: {
                    Label("同步", systemImage: "arrow.triangle.2.circlepath")
                }
                NavigationLink {
                    MacAboutView(openURL: openURL)
                } label: {
                    Label("关于", systemImage: "info.circle")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } detail: {
            MacAppearanceSettingsView(themeMode: $themeMode)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
