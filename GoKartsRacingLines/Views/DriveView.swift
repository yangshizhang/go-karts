import ARKit
import CoreLocation
import RealityKit
import SwiftUI
import UIKit

struct DriveView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var telemetry = LocationMotionService()
    @State private var showingTrackPicker = false

    var body: some View {
        ZStack(alignment: .top) {
            TrackMRView(track: appState.currentTrack, currentLocation: telemetry.latestLocation)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if appState.showDebugTelemetry {
                    TelemetryHUD(locationSpeed: telemetry.latestLocation?.speed, inertialOffset: telemetry.inertialOffsetMeters, pointCount: appState.currentTrack.racingLine.count)
                }

                HStack(spacing: 10) {
                    Button {
                        showingTrackPicker = true
                    } label: {
                        Label(appState.currentTrack.racingLine.isEmpty ? "选择赛道" : appState.currentTrack.name, systemImage: "map")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(.ultraThinMaterial, in: Capsule())

                    Text("开始页仅加载并显示已保存行车线")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                if appState.savedTracks.isEmpty {
                    Text("请先进入“绘制”手绘/圈选或实跑记录并保存赛道")
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 28)
                }

                Spacer()
            }
            .padding(.top, 16)
        }
        .navigationTitle("开始")
        .navigationBarTitleDisplayMode(.inline)
        .task { telemetry.start() }
        .onDisappear { telemetry.stop() }
        .sheet(isPresented: $showingTrackPicker) {
            DriveTrackPickerView()
                .environmentObject(appState)
        }
    }
}

private struct DriveTrackPickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if appState.savedTracks.isEmpty {
                    Text("暂无已保存赛道。请先到“绘制”中创建并保存。")
                        .foregroundStyle(.secondary)
                }

                ForEach(appState.savedTracks) { track in
                    Button {
                        appState.loadTrack(track)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(track.name)
                                .font(.headline)
                            Text("\(track.lapMode.rawValue) · 行车线 \(track.racingLine.count) 点 · 区域 \(track.boundary.count) 点")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("选择赛道")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

struct TrackMRView: UIViewRepresentable {
    let track: TrackDefinition
    let currentLocation: CLLocation?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.renderOptions.insert(.disableMotionBlur)

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        context.coordinator.installRoot(in: arView)
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.render(track: track, currentLocation: currentLocation, in: arView)
    }

    final class Coordinator {
        private let root = AnchorEntity(world: .zero)
        private var lastSignature = ""

        func installRoot(in arView: ARView) {
            guard root.scene == nil else { return }
            arView.scene.addAnchor(root)
        }

        func render(track: TrackDefinition, currentLocation: CLLocation?, in arView: ARView) {
            installRoot(in: arView)
            let origin = currentLocation?.coordinate ?? track.racingLine.first?.coordinate
            let signature = makeSignature(track: track, origin: origin)
            guard signature != lastSignature else { return }
            lastSignature = signature
            root.children.removeAll()

            guard let origin, track.racingLine.count > 1 else {
                root.addChild(makeFloatingLabel("请选择已保存赛道"))
                return
            }

            addGroundGrid(to: root)
            addLine(points: track.racingLine, origin: origin, to: root)
            addStartFinish(track: track, origin: origin, to: root)
        }

        private func addLine(points: [TrackPoint], origin: CLLocationCoordinate2D, to root: Entity) {
            let maximumSpeed = max(points.map(\.speed).max() ?? 0, 1)
            for pair in zip(points, points.dropFirst()) {
                let start = worldPosition(for: pair.0.coordinate, origin: origin)
                let end = worldPosition(for: pair.1.coordinate, origin: origin)
                let distance = simd_distance(start, end)
                guard distance > 0.15, distance < 80 else { continue }

                let material = UnlitMaterial(color: pair.1.uiColor(maximumSpeed: maximumSpeed))
                let mesh = MeshResource.generateBox(width: 0.42, height: 0.035, depth: distance)
                let entity = ModelEntity(mesh: mesh, materials: [material])
                entity.position = (start + end) / 2 + SIMD3<Float>(0, 0.025, 0)
                entity.look(at: end, from: entity.position, relativeTo: nil)
                root.addChild(entity)
            }
        }

        private func addStartFinish(track: TrackDefinition, origin: CLLocationCoordinate2D, to root: Entity) {
            let startPoint = track.startPoint ?? track.racingLine.first
            let finishPoint = track.lapMode == .closedCircuit ? startPoint : (track.finishPoint ?? track.racingLine.last)

            if let startPoint {
                root.addChild(marker(title: "START", color: .systemGreen, at: worldPosition(for: startPoint.coordinate, origin: origin)))
            }
            if let finishPoint {
                root.addChild(marker(title: "FINISH", color: .systemYellow, at: worldPosition(for: finishPoint.coordinate, origin: origin)))
            }
        }

        private func marker(title: String, color: UIColor, at position: SIMD3<Float>) -> Entity {
            let container = Entity()
            container.position = position + SIMD3<Float>(0, 0.08, 0)
            let disc = ModelEntity(mesh: .generateBox(width: 1.1, height: 0.05, depth: 1.1), materials: [UnlitMaterial(color: color.withAlphaComponent(0.85))])
            container.addChild(disc)

            let textMesh = MeshResource.generateText(title, extrusionDepth: 0.01, font: .boldSystemFont(ofSize: 0.28), containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping)
            let text = ModelEntity(mesh: textMesh, materials: [UnlitMaterial(color: .white)])
            text.position = SIMD3<Float>(-0.46, 0.08, 0.0)
            text.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
            container.addChild(text)
            return container
        }

        private func addGroundGrid(to root: Entity) {
            let material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.18))
            for offset in stride(from: -10, through: 10, by: 5) {
                let zLine = ModelEntity(mesh: .generateBox(width: 20, height: 0.01, depth: 0.025), materials: [material])
                zLine.position = SIMD3<Float>(0, 0.005, Float(offset))
                root.addChild(zLine)

                let xLine = ModelEntity(mesh: .generateBox(width: 0.025, height: 0.01, depth: 20), materials: [material])
                xLine.position = SIMD3<Float>(Float(offset), 0.005, 0)
                root.addChild(xLine)
            }
        }

        private func makeFloatingLabel(_ text: String) -> Entity {
            let mesh = MeshResource.generateText(text, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.18), containerFrame: CGRect(x: 0, y: 0, width: 2.4, height: 0.4), alignment: .center, lineBreakMode: .byWordWrapping)
            let entity = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
            entity.position = SIMD3<Float>(-1.2, 0.0, -1.2)
            return entity
        }

        private func worldPosition(for coordinate: CLLocationCoordinate2D, origin: CLLocationCoordinate2D) -> SIMD3<Float> {
            let metersPerDegreeLatitude = 111_320.0
            let metersPerDegreeLongitude = cos(origin.latitude * .pi / 180) * metersPerDegreeLatitude
            let east = (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude
            let north = (coordinate.latitude - origin.latitude) * metersPerDegreeLatitude
            return SIMD3<Float>(Float(east), 0, Float(-north))
        }

        private func makeSignature(track: TrackDefinition, origin: CLLocationCoordinate2D?) -> String {
            let originText = origin.map { "\(round($0.latitude * 100000) / 100000),\(round($0.longitude * 100000) / 100000)" } ?? "none"
            return "\(track.updatedAt.timeIntervalSince1970)-\(track.racingLine.count)-\(originText)"
        }
    }
}

private struct TelemetryHUD: View {
    let locationSpeed: Double?
    let inertialOffset: Double
    let pointCount: Int

    var body: some View {
        HStack(spacing: 16) {
            Label("\(Int(max(locationSpeed ?? 0, 0) * 3.6)) km/h", systemImage: "speedometer")
            Label(String(format: "IMU %.1fm", inertialOffset), systemImage: "gyroscope")
            Label("\(pointCount) 点", systemImage: "point.3.connected.trianglepath.dotted")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
