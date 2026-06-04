import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var currentTrack = TrackDefinition()
    @Published private(set) var savedTracks: [TrackDefinition] = []
    @Published var renderFastStrokeThreshold: Double = 480
    @Published var lineProjectionMeters: Double = 80
    @Published var showDebugTelemetry = true

    private let storageKey = "savedTracks.v1"

    init() {
        loadTracks()
    }

    func replaceRacingLine(with points: [TrackPoint]) {
        currentTrack.racingLine = points
        currentTrack.updatedAt = Date()
    }

    func updateBoundary(_ points: [TrackPoint]) {
        currentTrack.boundary = points
        currentTrack.updatedAt = Date()
    }

    func saveCurrentTrack(name: String, lapMode: LapMode) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTrack.name = trimmedName.isEmpty ? "未命名赛道" : trimmedName
        currentTrack.lapMode = lapMode
        currentTrack.updatedAt = Date()

        if let index = savedTracks.firstIndex(where: { $0.id == currentTrack.id }) {
            savedTracks[index] = currentTrack
        } else {
            savedTracks.insert(currentTrack, at: 0)
        }
        persistTracks()
    }

    func loadTrack(_ track: TrackDefinition) {
        currentTrack = track
    }

    func newTrack() {
        currentTrack = TrackDefinition()
    }

    func deleteTracks(at offsets: IndexSet) {
        savedTracks.remove(atOffsets: offsets)
        persistTracks()
    }

    private func loadTracks() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let tracks = try? JSONDecoder().decode([TrackDefinition].self, from: data) else { return }
        savedTracks = tracks.sorted { $0.updatedAt > $1.updatedAt }
        if let first = savedTracks.first {
            currentTrack = first
        }
    }

    private func persistTracks() {
        guard let data = try? JSONEncoder().encode(savedTracks) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
