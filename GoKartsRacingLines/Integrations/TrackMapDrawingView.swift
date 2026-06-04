import CoreLocation
import MapKit
import SwiftUI

#if canImport(MAMapKit)
import MAMapKit
#endif

struct CoordinateValue {
    var latitude: Double
    var longitude: Double

    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }
}

struct TrackMapDrawingView: View {
    let selectedTool: DrawingTool
    let onDraw: (CoordinateValue, CGPoint, Date) -> Void

    var body: some View {
        #if canImport(MAMapKit)
        if Bundle.main.hasAMapKey {
            AMapDrawingRepresentable(selectedTool: selectedTool, onDraw: onDraw)
        } else {
            MapKitDrawingRepresentable(selectedTool: selectedTool, onDraw: onDraw)
        }
        #else
        MapKitDrawingRepresentable(selectedTool: selectedTool, onDraw: onDraw)
        #endif
    }
}

private extension Bundle {
    var hasAMapKey: Bool {
        guard let key = object(forInfoDictionaryKey: "AMapApiKey") as? String else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#if canImport(MAMapKit)
struct AMapDrawingRepresentable: UIViewRepresentable {
    let selectedTool: DrawingTool
    let onDraw: (CoordinateValue, CGPoint, Date) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDraw: onDraw) }

    func makeUIView(context: Context) -> MAMapView {
        let mapView = MAMapView(frame: .zero)
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.zoomLevel = 18
        context.coordinator.attach(to: mapView)
        return mapView
    }

    func updateUIView(_ uiView: MAMapView, context: Context) {
        context.coordinator.onDraw = onDraw
    }

    final class Coordinator: NSObject {
        var onDraw: (CoordinateValue, CGPoint, Date) -> Void
        weak var mapView: MAMapView?

        init(onDraw: @escaping (CoordinateValue, CGPoint, Date) -> Void) {
            self.onDraw = onDraw
        }

        func attach(to mapView: MAMapView) {
            self.mapView = mapView
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.minimumNumberOfTouches = 1
            mapView.addGestureRecognizer(pan)
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let mapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onDraw(CoordinateValue(coordinate), point, Date())
        }
    }
}
#endif

struct MapKitDrawingRepresentable: UIViewRepresentable {
    let selectedTool: DrawingTool
    let onDraw: (CoordinateValue, CGPoint, Date) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDraw: onDraw) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        context.coordinator.attach(to: mapView)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.onDraw = onDraw
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDraw: (CoordinateValue, CGPoint, Date) -> Void
        weak var mapView: MKMapView?

        init(onDraw: @escaping (CoordinateValue, CGPoint, Date) -> Void) {
            self.onDraw = onDraw
        }

        func attach(to mapView: MKMapView) {
            self.mapView = mapView
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.minimumNumberOfTouches = 1
            pan.delegate = self
            mapView.addGestureRecognizer(pan)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let mapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onDraw(CoordinateValue(coordinate), point, Date())
        }
    }
}
