import SwiftUI

struct DriveView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var cameraService = CameraService()
    @StateObject private var telemetry = LocationMotionService()

    var body: some View {
        ZStack(alignment: .top) {
            CameraPreviewView(session: cameraService.session)
                .ignoresSafeArea()
            RacingLineOverlay(track: appState.currentTrack, currentLocation: telemetry.latestLocation, headingDegrees: telemetry.latestHeading?.trueHeading, projectionMeters: appState.lineProjectionMeters)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                if appState.showDebugTelemetry {
                    TelemetryHUD(locationSpeed: telemetry.latestLocation?.speed, pointCount: appState.currentTrack.racingLine.count, isRecording: telemetry.isRecording)
                }
                Spacer()
                Button(action: toggleRecording) {
                    Label(telemetry.isRecording ? "结束实跑生成行车线" : "实际跑设置行车线", systemImage: telemetry.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .frame(height: 54)
                        .background(telemetry.isRecording ? .red : .green, in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
        .navigationTitle("开始")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            cameraService.requestAndStart()
            telemetry.start()
        }
        .onDisappear {
            cameraService.stop()
            telemetry.stop()
        }
    }

    private func toggleRecording() {
        if telemetry.isRecording {
            appState.replaceRacingLine(with: telemetry.stopRecording())
        } else {
            telemetry.startRecording()
        }
    }
}

private struct TelemetryHUD: View {
    let locationSpeed: Double?
    let pointCount: Int
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 16) {
            Label("\(Int(max(locationSpeed ?? 0, 0) * 3.6)) km/h", systemImage: "speedometer")
            Label("\(pointCount) 点", systemImage: "point.3.connected.trianglepath.dotted")
            if isRecording { Text("REC").foregroundStyle(.red).fontWeight(.black) }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
