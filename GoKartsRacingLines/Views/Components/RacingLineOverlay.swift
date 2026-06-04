import CoreLocation
import SwiftUI

struct RacingLineOverlay: View {
    let track: TrackDefinition
    let currentLocation: CLLocation?
    let headingDegrees: Double?
    let projectionMeters: Double

    var body: some View {
        Canvas { context, size in
            drawHorizon(in: &context, size: size)
            drawProjectedLine(in: &context, size: size)
        }
        .allowsHitTesting(false)
    }

    private func drawHorizon(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.58)
        let left = CGPoint(x: size.width * 0.18, y: size.height * 0.76)
        let right = CGPoint(x: size.width * 0.82, y: size.height * 0.76)
        context.stroke(Path { path in
            path.move(to: center)
            path.addLine(to: left)
            path.move(to: center)
            path.addLine(to: right)
        }, with: .color(.white.opacity(0.28)), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
    }

    private func drawProjectedLine(in context: inout GraphicsContext, size: CGSize) {
        guard let currentLocation, track.racingLine.count > 1 else { return }
        let heading = (headingDegrees ?? currentLocation.course).degreesToRadians
        let visiblePoints = track.racingLine
            .map { projectedPoint(for: $0, origin: currentLocation.coordinate, heading: heading, size: size) }
            .filter { $0.depth > 0 && $0.depth < projectionMeters }

        guard visiblePoints.count > 1 else { return }
        for pair in zip(visiblePoints, visiblePoints.dropFirst()) {
            var path = Path()
            path.move(to: pair.0.point)
            path.addLine(to: pair.1.point)
            context.stroke(path, with: .color(pair.1.signal.color.opacity(0.92)), style: StrokeStyle(lineWidth: max(5, 12 - pair.1.depth / 10), lineCap: .round, lineJoin: .round))
        }
    }

    private func projectedPoint(for trackPoint: TrackPoint, origin: CLLocationCoordinate2D, heading: Double, size: CGSize) -> (point: CGPoint, depth: Double, signal: RacingLineSignal) {
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLon = cos(origin.latitude.degreesToRadians) * metersPerDegreeLat
        let east = (trackPoint.longitude - origin.longitude) * metersPerDegreeLon
        let north = (trackPoint.latitude - origin.latitude) * metersPerDegreeLat
        let forward = north * cos(heading) + east * sin(heading)
        let lateral = east * cos(heading) - north * sin(heading)
        let depth = max(forward, 0.1)
        let perspective = min(1.0, 18.0 / depth)
        let x = size.width / 2 + lateral * perspective * 5
        let y = size.height * 0.82 - depth / projectionMeters * size.height * 0.38
        return (CGPoint(x: x, y: y), depth, trackPoint.signal)
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
}
