import SwiftUI

enum DrawingTool: String, CaseIterable, Identifiable {
    case boundary = "圈选赛道区域"
    case racingLine = "手绘行车线"

    var id: String { rawValue }
}

struct DrawingSample: Identifiable {
    let id = UUID()
    var point: CGPoint
    var signal: RacingLineSignal
}

struct DrawingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTool: DrawingTool = .boundary
    @State private var drawingSamples: [DrawingSample] = []
    @State private var lastDragPoint: CGPoint?
    @State private var lastDragDate: Date?

    var body: some View {
        VStack(spacing: 0) {
            controlPanel
            ZStack {
                TrackMapDrawingView(selectedTool: selectedTool) { coordinate, screenPoint, timestamp in
                    appendPoint(coordinate: coordinate, screenPoint: screenPoint, timestamp: timestamp)
                }
                DrawingStrokeOverlay(samples: drawingSamples)
            }
        }
        .navigationTitle("绘制")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            Picker("绘制模式", selection: $selectedTool) {
                ForEach(DrawingTool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            Picker("单圈/多圈", selection: $appState.currentTrack.lapMode) {
                ForEach(LapMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            HStack {
                Button("清空当前") { clearSelectedTool() }
                Spacer()
                Text("区域 \(appState.currentTrack.boundary.count) 点 · 线 \(appState.currentTrack.racingLine.count) 点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial)
    }

    private func appendPoint(coordinate: CoordinateValue, screenPoint: CGPoint, timestamp: Date) {
        let speed = dragSpeed(from: screenPoint, at: timestamp)
        let signal: RacingLineSignal = speed > appState.renderFastStrokeThreshold ? .caution : .accelerate
        let point = TrackPoint(coordinate: coordinate.locationCoordinate, speed: speed, timestamp: timestamp, signal: signal)

        switch selectedTool {
        case .boundary:
            appState.currentTrack.boundary.append(point)
        case .racingLine:
            appState.currentTrack.racingLine.append(point)
        }
        drawingSamples.append(DrawingSample(point: screenPoint, signal: signal))
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
        drawingSamples.removeAll()
        lastDragPoint = nil
        lastDragDate = nil
    }
}

private struct DrawingStrokeOverlay: View {
    let samples: [DrawingSample]

    var body: some View {
        Canvas { context, _ in
            guard samples.count > 1 else { return }
            for pair in zip(samples, samples.dropFirst()) {
                var path = Path()
                path.move(to: pair.0.point)
                path.addLine(to: pair.1.point)
                context.stroke(path, with: .color(pair.1.signal.color), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
    }
}
