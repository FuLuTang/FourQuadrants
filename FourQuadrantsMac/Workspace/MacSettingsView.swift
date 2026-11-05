import SwiftUI

struct MacSettingsView: View {
    @AppStorage("themeMode") private var themeMode = 0
    @Environment(\.openURL) private var openURL

    /// 标准 macOS 设置窗口：顶部分段式标签页切换，宽度固定，高度随内容变化。
    var body: some View {
        TabView {
            Tab("外观", systemImage: "paintbrush") {
                MacAppearanceSettingsView(themeMode: $themeMode)
            }
            Tab("同步", systemImage: "arrow.triangle.2.circlepath") {
                MacSyncSettingsView()
            }
            Tab("关于", systemImage: "info.circle") {
                MacAboutView(openURL: openURL)
            }
        }
        .frame(minWidth: 560, idealWidth: 600, maxWidth: 640)
    }
}
