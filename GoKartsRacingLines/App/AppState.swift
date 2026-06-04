import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var currentTrack = TrackDefinition()
    @Published var renderFastStrokeThreshold: Double = 480
    @Published var lineProjectionMeters: Double = 80
    @Published var showDebugTelemetry = true

    func replaceRacingLine(with points: [TrackPoint]) {
        currentTrack.racingLine = points
        currentTrack.updatedAt = Date()
    }

    func updateBoundary(_ points: [TrackPoint]) {
        currentTrack.boundary = points
        currentTrack.updatedAt = Date()
    }
}
