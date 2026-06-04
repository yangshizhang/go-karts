import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("行车线渲染") {
                VStack(alignment: .leading) {
                    Text("手指速度阈值：\(Int(appState.renderFastStrokeThreshold)) pt/s")
                    Slider(value: $appState.renderFastStrokeThreshold, in: 120...1200, step: 20)
                }
                VStack(alignment: .leading) {
                    Text("前方投影距离：\(Int(appState.lineProjectionMeters)) m")
                    Slider(value: $appState.lineProjectionMeters, in: 30...200, step: 5)
                }
                Toggle("显示调试遥测", isOn: $appState.showDebugTelemetry)
            }
            Section("赛道") {
                TextField("名称", text: $appState.currentTrack.name)
                Picker("模式", selection: $appState.currentTrack.lapMode) {
                    ForEach(LapMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
        }
        .navigationTitle("设置")
    }
}
