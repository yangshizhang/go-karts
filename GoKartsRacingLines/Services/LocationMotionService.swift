import CoreLocation
import CoreMotion
import Foundation

@MainActor
final class LocationMotionService: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var latestLocation: CLLocation?
    @Published var rawLocation: CLLocation?
    @Published var latestHeading: CLHeading?
    @Published var attitude: CMAttitude?
    @Published var recordedPoints: [TrackPoint] = []
    @Published var isRecording = false
    @Published var inertialOffsetMeters: Double = 0

    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    private var lastGPSLocation: CLLocation?
    private var fusedCoordinate: CLLocationCoordinate2D?
    private var inertialVelocityEast = 0.0
    private var inertialVelocityNorth = 0.0
    private var inertialOffsetEast = 0.0
    private var inertialOffsetNorth = 0.0
    private var lastMotionTimestamp: TimeInterval?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
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
        let referenceFrame: CMAttitudeReferenceFrame = CMMotionManager.availableAttitudeReferenceFrames().contains(.xTrueNorthZVertical) ? .xTrueNorthZVertical : .xArbitraryCorrectedZVertical
        motionManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            Task { @MainActor in
                self?.attitude = motion.attitude
                self?.integrateInertialMotion(motion)
            }
        }
    }

    private func integrateInertialMotion(_ motion: CMDeviceMotion) {
        defer { lastMotionTimestamp = motion.timestamp }
        guard let lastMotionTimestamp, let fusedCoordinate else { return }
        let deltaTime = min(max(motion.timestamp - lastMotionTimestamp, 0), 0.1)
        guard deltaTime > 0 else { return }

        let acceleration = motion.userAcceleration
        let matrix = motion.attitude.rotationMatrix
        let worldX = matrix.m11 * acceleration.x + matrix.m12 * acceleration.y + matrix.m13 * acceleration.z
        let worldY = matrix.m21 * acceleration.x + matrix.m22 * acceleration.y + matrix.m23 * acceleration.z
        let accelerationEast = worldX * 9.80665
        let accelerationNorth = worldY * 9.80665

        inertialVelocityEast = (inertialVelocityEast + accelerationEast * deltaTime) * 0.985
        inertialVelocityNorth = (inertialVelocityNorth + accelerationNorth * deltaTime) * 0.985
        inertialOffsetEast += inertialVelocityEast * deltaTime
        inertialOffsetNorth += inertialVelocityNorth * deltaTime

        let clampedEast = min(max(inertialOffsetEast, -8), 8)
        let clampedNorth = min(max(inertialOffsetNorth, -8), 8)
        inertialOffsetMeters = hypot(clampedEast, clampedNorth)
        let assistedCoordinate = fusedCoordinate.shifted(eastMeters: clampedEast, northMeters: clampedNorth)
        latestLocation = CLLocation(coordinate: assistedCoordinate, altitude: rawLocation?.altitude ?? 0, horizontalAccuracy: rawLocation?.horizontalAccuracy ?? 8, verticalAccuracy: rawLocation?.verticalAccuracy ?? -1, course: rawLocation?.course ?? -1, speed: max(rawLocation?.speed ?? 0, 0), timestamp: Date())
    }

    private func acceptGPSLocation(_ location: CLLocation) {
        rawLocation = location
        lastGPSLocation = location
        let gpsCoordinate = location.coordinate
        if let fusedCoordinate {
            let gpsWeight = location.horizontalAccuracy <= 6 ? 0.75 : 0.45
            let metersPerDegreeLatitude = 111_320.0
            let metersPerDegreeLongitude = cos(gpsCoordinate.latitude * .pi / 180) * metersPerDegreeLatitude
            let east = (gpsCoordinate.longitude - fusedCoordinate.longitude) * metersPerDegreeLongitude
            let north = (gpsCoordinate.latitude - fusedCoordinate.latitude) * metersPerDegreeLatitude
            self.fusedCoordinate = fusedCoordinate.shifted(eastMeters: east * gpsWeight, northMeters: north * gpsWeight)
        } else {
            fusedCoordinate = gpsCoordinate
        }

        inertialOffsetEast *= 0.25
        inertialOffsetNorth *= 0.25
        inertialVelocityEast *= 0.35
        inertialVelocityNorth *= 0.35

        guard let fusedCoordinate else { return }
        let assistedCoordinate = fusedCoordinate.shifted(eastMeters: inertialOffsetEast, northMeters: inertialOffsetNorth)
        let assistedLocation = CLLocation(coordinate: assistedCoordinate, altitude: location.altitude, horizontalAccuracy: location.horizontalAccuracy, verticalAccuracy: location.verticalAccuracy, course: location.course, speed: max(location.speed, 0), timestamp: location.timestamp)
        latestLocation = assistedLocation

        guard isRecording else { return }
        let signal = RacingLineSignal(speed: max(location.speed, 0), fastThreshold: 8)
        recordedPoints.append(TrackPoint(coordinate: assistedLocation.coordinate, altitude: assistedLocation.altitude, speed: max(assistedLocation.speed, 0), timestamp: assistedLocation.timestamp, signal: signal))
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
            acceptGPSLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            latestHeading = newHeading
        }
    }
}
