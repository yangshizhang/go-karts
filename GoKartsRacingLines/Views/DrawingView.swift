import SwiftUI

enum DrawingTool: String, CaseIterable, Identifiable {
    case boundary = "圈选赛道区域"
    case racingLine = "手绘行车线"

    var id: String { rawValue }
}

struct DrawingSample: Identifiable {
    let id = UUID()
    var point: CGPoint
    var speed: Double
}

struct DrawingView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var telemetry = LocationMotionService()
    @State private var selectedTool: DrawingTool = .boundary
    @State private var drawingSamples: [DrawingSample] = []
    @State private var lastDragPoint: CGPoint?
    @State private var lastDragDate: Date?
    @State private var showingSaveSheet = false
    @State private var showingTrackManager = false
    @State private var draftTrackName = ""
    @State private var draftLapMode: LapMode = .closedCircuit

    var body: some View {
        VStack(spacing: 0) {
            controlPanel
            ZStack(alignment: .bottom) {
                TrackMapDrawingView(selectedTool: selectedTool) { coordinate, screenPoint, timestamp in
                    appendPoint(coordinate: coordinate, screenPoint: screenPoint, timestamp: timestamp)
                }
                DrawingStrokeOverlay(samples: drawingSamples, maximumSpeed: appState.renderFastStrokeThreshold)
                Text("单指绘画/圈选 · 双指移动地图 · 低速黄/高速绿")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 16)
            }
        }
        .navigationTitle("绘制")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("管理") { showingTrackManager = true }
                Button("保存") { prepareSave() }
                    .disabled(appState.currentTrack.boundary.isEmpty && appState.currentTrack.racingLine.isEmpty)
            }
        }
        .sheet(isPresented: $showingSaveSheet) {
            SaveTrackSheet(trackName: $draftTrackName, lapMode: $draftLapMode) {
                appState.saveCurrentTrack(name: draftTrackName, lapMode: draftLapMode)
                showingSaveSheet = false
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingTrackManager) {
            TrackManagerView()
                .environmentObject(appState)
        }
        .task { telemetry.start() }
        .onDisappear { telemetry.stop() }
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            Picker("绘制模式", selection: $selectedTool) {
                ForEach(DrawingTool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            Picker("赛道类型", selection: $appState.currentTrack.lapMode) {
                ForEach(LapMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            HStack(spacing: 12) {
                Button("新赛道") {
                    appState.newTrack()
                    resetDrawingState()
                }
                Button("清空当前") { clearSelectedTool() }
                Button(telemetry.isRecording ? "结束实录" : "实跑记录") { toggleLiveRecording() }
                    .foregroundStyle(telemetry.isRecording ? .red : .green)
                Spacer()
            }

            HStack {
                Text("区域 \(appState.currentTrack.boundary.count) 点 · 线 \(appState.currentTrack.racingLine.count) 点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if telemetry.isRecording {
                    Label("REC", systemImage: "record.circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
    }

    private func appendPoint(coordinate: CoordinateValue, screenPoint: CGPoint, timestamp: Date) {
        guard !telemetry.isRecording else { return }
        let speed = dragSpeed(from: screenPoint, at: timestamp)
        let signal = RacingLineSignal(speed: speed, fastThreshold: appState.renderFastStrokeThreshold)
        let point = TrackPoint(coordinate: coordinate.locationCoordinate, speed: speed, timestamp: timestamp, signal: signal)

        switch selectedTool {
        case .boundary:
            appState.currentTrack.boundary.append(point)
        case .racingLine:
            appState.currentTrack.racingLine.append(point)
        }
        appState.currentTrack.updatedAt = Date()
        drawingSamples.append(DrawingSample(point: screenPoint, speed: speed))
    }

    private func dragSpeed(from point: CGPoint, at timestamp: Date) -> Double {
        defer {
            lastDragPoint = point
            lastDragDate = timestamp
        }
        guard let lastDragPoint, let lastDragDate else { return 0 }
        let distance = hypot(point.x - lastDragPoint.x, point.y - lastDragPoint.y)
        let interval = max(timestamp.timeIntervalSince(lastDragDate), 0.016)
        return distance / interval
    }

    private func clearSelectedTool() {
        switch selectedTool {
        case .boundary:
            appState.currentTrack.boundary.removeAll()
        case .racingLine:
            appState.currentTrack.racingLine.removeAll()
        }
        appState.currentTrack.updatedAt = Date()
        resetDrawingState()
    }

    private func resetDrawingState() {
        drawingSamples.removeAll()
        lastDragPoint = nil
        lastDragDate = nil
    }

    private func prepareSave() {
        draftTrackName = appState.currentTrack.name == "未命名赛道" ? "" : appState.currentTrack.name
        draftLapMode = appState.currentTrack.lapMode
        showingSaveSheet = true
    }

    private func toggleLiveRecording() {
        if telemetry.isRecording {
            let points = telemetry.stopRecording()
            appState.replaceRacingLine(with: points)
            selectedTool = .racingLine
            resetDrawingState()
            prepareSave()
        } else {
            selectedTool = .racingLine
            telemetry.startRecording()
        }
    }
}

private struct DrawingStrokeOverlay: View {
    let samples: [DrawingSample]
    let maximumSpeed: Double

    var body: some View {
        Canvas { context, _ in
            guard samples.count > 1 else { return }
            for pair in zip(samples, samples.dropFirst()) {
                var path = Path()
                path.move(to: pair.0.point)
                path.addLine(to: pair.1.point)
                let ratio = min(max(pair.1.speed / max(maximumSpeed, 1), 0), 1)
                let color = Color(red: 1 - ratio, green: 1, blue: 0)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SaveTrackSheet: View {
    @Binding var trackName: String
    @Binding var lapMode: LapMode
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("保存赛道") {
                    TextField("赛道名", text: $trackName)
                    Picker("类型", selection: $lapMode) {
                        ForEach(LapMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                Section {
                    Button("保存") { onSave() }
                        .disabled(trackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("赛道信息")
        }
    }
}

private struct TrackManagerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    appState.newTrack()
                    dismiss()
                } label: {
                    Label("新建空赛道", systemImage: "plus.circle")
                }

                ForEach(appState.savedTracks) { track in
                    Button {
                        appState.loadTrack(track)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.name).font(.headline)
                            Text("\(track.lapMode.rawValue) · 区域 \(track.boundary.count) 点 · 线 \(track.racingLine.count) 点")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: appState.deleteTracks)
            }
            .navigationTitle("赛道管理")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
