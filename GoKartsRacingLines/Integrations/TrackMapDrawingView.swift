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

final class DrawingMapContainer<MapView: UIView>: UIView {
    let mapView: MapView
    private let overlayView = UIView()
    var coordinateForPoint: ((CGPoint) -> CLLocationCoordinate2D?)?
    var onDraw: ((CoordinateValue, CGPoint, Date) -> Void)?

    init(mapView: MapView) {
        self.mapView = mapView
        super.init(frame: .zero)
        addSubview(mapView)
        addSubview(overlayView)
        overlayView.backgroundColor = .clear
        installDrawingGesture()
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        mapView.frame = bounds
        overlayView.frame = bounds
    }

    private func installDrawingGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDrawingPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        overlayView.addGestureRecognizer(pan)
    }

    @objc private func handleDrawingPan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.numberOfTouches <= 1 else { return }
        let point = gesture.location(in: mapView)
        guard let coordinate = coordinateForPoint?(point) else { return }
        onDraw?(CoordinateValue(coordinate), point, Date())
    }
}

private extension Bundle {
    var hasAMapKey: Bool {
        guard let key = object(forInfoDictionaryKey: "AMapApiKey") as? String else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private func requireTwoFingerMapPan(on view: UIView) {
    view.gestureRecognizers?.forEach { recognizer in
        if let pan = recognizer as? UIPanGestureRecognizer {
            pan.minimumNumberOfTouches = max(pan.minimumNumberOfTouches, 2)
        }
    }
    view.subviews.forEach { requireTwoFingerMapPan(on: $0) }
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

#if canImport(MAMapKit)
struct AMapDrawingRepresentable: UIViewRepresentable {
    typealias UIViewType = DrawingMapContainer<MAMapView>
    let selectedTool: DrawingTool
    let onDraw: (CoordinateValue, CGPoint, Date) -> Void

    func makeUIView(context: Context) -> UIViewType {
        let mapView = MAMapView(frame: .zero)
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.zoomLevel = 18
        let container = DrawingMapContainer(mapView: mapView)
        container.coordinateForPoint = { [weak mapView] point in mapView?.convert(point, toCoordinateFrom: mapView) }
        container.onDraw = onDraw
        DispatchQueue.main.async { requireTwoFingerMapPan(on: mapView) }
        return container
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.onDraw = onDraw
        DispatchQueue.main.async { requireTwoFingerMapPan(on: uiView.mapView) }
    }
}
#endif

struct MapKitDrawingRepresentable: UIViewRepresentable {
    typealias UIViewType = DrawingMapContainer<MKMapView>
    let selectedTool: DrawingTool
    let onDraw: (CoordinateValue, CGPoint, Date) -> Void

    func makeUIView(context: Context) -> UIViewType {
        let mapView = MKMapView(frame: .zero)
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        let container = DrawingMapContainer(mapView: mapView)
        container.coordinateForPoint = { [weak mapView] point in mapView?.convert(point, toCoordinateFrom: mapView) }
        container.onDraw = onDraw
        DispatchQueue.main.async { requireTwoFingerMapPan(on: mapView) }
        return container
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.onDraw = onDraw
        DispatchQueue.main.async { requireTwoFingerMapPan(on: uiView.mapView) }
    }
}
