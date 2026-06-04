import CoreLocation
import Foundation
import SwiftUI

enum LapMode: String, CaseIterable, Identifiable, Codable {
    case pointToPoint = "单圈异地起终点"
    case closedCircuit = "多圈同地起终点"

    var id: String { rawValue }
}

enum RacingLineSignal: String, Codable {
    case accelerate
    case caution

    var color: Color {
        switch self {
        case .accelerate: .green
        case .caution: .red
        }
    }
}

struct TrackPoint: Identifiable, Codable, Hashable {
    let id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var speed: Double
    var timestamp: Date
    var signal: RacingLineSignal

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, altitude: Double = 0, speed: Double = 0, timestamp: Date = Date(), signal: RacingLineSignal = .accelerate) {
        self.id = id
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        self.altitude = altitude
        self.speed = speed
        self.timestamp = timestamp
        self.signal = signal
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TrackDefinition: Identifiable, Codable {
    var id = UUID()
    var name = "未命名赛道"
    var lapMode: LapMode = .closedCircuit
    var boundary: [TrackPoint] = []
    var racingLine: [TrackPoint] = []
    var startPoint: TrackPoint?
    var finishPoint: TrackPoint?
    var updatedAt = Date()
}

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
