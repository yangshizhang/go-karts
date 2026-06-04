import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, .gray.opacity(0.45), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 28) {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("GO KARTS")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("AR Racing Line")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    VStack(spacing: 16) {
                        NavigationLink(destination: DriveView()) {
                            HomeActionButton(title: "开始", systemImage: "flag.checkered")
                        }
                        NavigationLink(destination: SettingsView()) {
                            HomeActionButton(title: "设置", systemImage: "slider.horizontal.3")
                        }
                        NavigationLink(destination: DrawingView()) {
                            HomeActionButton(title: "绘制", systemImage: "map")
                        }
                    }
                    .padding(.horizontal, 28)
                    Spacer()
                    Text(appState.currentTrack.racingLine.isEmpty ? "请先绘制或实跑生成行车线" : "当前行车线：\(appState.currentTrack.racingLine.count) 个点")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 28)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct HomeActionButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            Image(systemName: "chevron.right")
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 22)
        .frame(height: 64)
        .background(.green, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
