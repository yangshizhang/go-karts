import CoreLocation
import CoreMotion
import Foundation

@MainActor
final class LocationMotionService: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var latestLocation: CLLocation?
    @Published var latestHeading: CLHeading?
    @Published var attitude: CMAttitude?
    @Published var recordedPoints: [TrackPoint] = []
    @Published var isRecording = false

    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 1
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }

    func start() {
        requestPermissions()
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        startMotionUpdates()
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        motionManager.stopDeviceMotionUpdates()
    }

    func startRecording() {
        recordedPoints.removeAll()
        isRecording = true
    }

    func stopRecording() -> [TrackPoint] {
        isRecording = false
        return recordedPoints
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            Task { @MainActor in
                self?.attitude = motion?.attitude
            }
        }
    }
}

extension LocationMotionService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            latestLocation = location
            guard isRecording else { return }
            let signal: RacingLineSignal = location.speed > 8 ? .caution : .accelerate
            recordedPoints.append(TrackPoint(coordinate: location.coordinate, altitude: location.altitude, speed: max(location.speed, 0), timestamp: location.timestamp, signal: signal))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            latestHeading = newHeading
        }
    }
}
