import SwiftUI

struct MacAboutView: View {
    let openURL: OpenURLAction

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("四象限").font(.title2.weight(.semibold))
                        Text("Four Quadrants").foregroundStyle(.secondary)
                        Text("版本 \(version)").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("产品") {
                LabeledContent("技术", value: "SwiftUI · SwiftData")
                Text("用清晰的四象限视图梳理任务、日期与日程。")
                    .foregroundStyle(.secondary)
            }

            Section("帮助与反馈") {
                Button {
                    if let url = URL(string: "https://github.com/fulutang/FourQuadrants") { openURL(url) }
                } label: {
                    Label("项目主页", systemImage: "link")
                }
                Button {
                    if let url = URL(string: "mailto:tanghaochen0506@hotmail.com?subject=FourQuadrants%20Feedback") { openURL(url) }
                } label: {
                    Label("发送反馈", systemImage: "envelope")
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 720, alignment: .leading)
        .padding(20)
    }
}
