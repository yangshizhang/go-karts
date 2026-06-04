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
    case braking

    init(speed: Double, fastThreshold: Double) {
        self = speed >= fastThreshold ? .accelerate : .braking
    }

    var color: Color {
        switch self {
        case .accelerate: .green
        case .braking: .yellow
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "accelerate": self = .accelerate
        case "braking", "caution": self = .braking
        default: self = .braking
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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

extension TrackPoint {
    func normalizedSpeed(maximum: Double) -> Double {
        guard maximum > 0 else { return 0 }
        return min(max(speed / maximum, 0), 1)
    }

    func swiftUIColor(maximumSpeed: Double) -> Color {
        Color(uiColor: uiColor(maximumSpeed: maximumSpeed))
    }

    func uiColor(maximumSpeed: Double) -> UIColor {
        let ratio = CGFloat(normalizedSpeed(maximum: maximumSpeed))
        let red = 1.0 - ratio
        let green: CGFloat = 1.0
        return UIColor(red: red, green: green, blue: 0, alpha: 0.92)
    }
}

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }

    func shifted(eastMeters: Double, northMeters: Double) -> CLLocationCoordinate2D {
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = cos(latitude * .pi / 180) * metersPerDegreeLatitude
        return CLLocationCoordinate2D(latitude: latitude + northMeters / metersPerDegreeLatitude, longitude: longitude + eastMeters / metersPerDegreeLongitude)
    }
}
