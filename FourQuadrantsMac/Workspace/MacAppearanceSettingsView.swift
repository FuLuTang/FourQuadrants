import SwiftUI

struct MacAppearanceSettingsView: View {
    @Binding var themeMode: Int

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: $themeMode) {
                    Text("自动").tag(0)
                    Text("浅色").tag(1)
                    Text("深色").tag(2)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 720, alignment: .leading)
        .padding(20)
    }
}
