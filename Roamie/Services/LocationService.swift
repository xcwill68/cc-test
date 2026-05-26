import Foundation
import CoreLocation

actor LocationService: NSObject {
    static let shared = LocationService()

    // CLLocationManager must run on main thread
    @MainActor private let manager = CLLocationManager()
    private var locationContinuation: AsyncStream<CLLocation>.Continuation?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private var recordedLocations: [CLLocation] = []
    private var isRecording = false

    var locationStream: AsyncStream<CLLocation> {
        AsyncStream { continuation in
            self.locationContinuation = continuation
            continuation.onTermination = { _ in }
        }
    }

    override init() {
        super.init()
        Task { @MainActor [self] in
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            let status = manager.authorizationStatus
            await self.handle(status: status)
        }
    }

    @discardableResult
    func requestPermission() async -> CLAuthorizationStatus {
        guard authorizationStatus == .notDetermined else { return authorizationStatus }
        return await withCheckedContinuation { continuation in
            self.authContinuation = continuation
            Task { @MainActor [self] in
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    func startUpdating() {
        Task { @MainActor [self] in manager.startUpdatingLocation() }
    }

    func stopUpdating() {
        Task { @MainActor [self] in manager.stopUpdatingLocation() }
    }

    func startRecording() {
        recordedLocations = []
        isRecording = true
        Task { @MainActor [self] in manager.startUpdatingLocation() }
    }

    func stopRecording() -> [CLLocation] {
        isRecording = false
        Task { @MainActor [self] in manager.stopUpdatingLocation() }
        return recordedLocations
    }

    func reverseGeocode(_ location: CLLocation) async throws -> (name: String, subtitle: String?) {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let p = placemarks.first else { throw LocationError.noPlacemark }
        let name = p.locality ?? p.name ?? "未知位置"
        let parts = [p.administrativeArea, p.country].compactMap { $0 }
        return (name, parts.isEmpty ? nil : parts.joined(separator: ", "))
    }

    func getCurrentLocation() async throws -> CLLocation {
        await requestPermission()
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        else { throw LocationError.permissionDenied }
        startUpdating()
        for await location in locationStream {
            stopUpdating()
            return location
        }
        throw LocationError.unavailable
    }

    enum LocationError: LocalizedError {
        case noPlacemark, unavailable, permissionDenied
        var errorDescription: String? {
            switch self {
            case .noPlacemark:      return "无法解析该位置"
            case .unavailable:      return "当前位置不可用"
            case .permissionDenied: return "请在设置中开启位置权限"
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { await self.handle(location: location) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { await self.handle(status: manager.authorizationStatus) }
    }

    private func handle(location: CLLocation) {
        locationContinuation?.yield(location)
        if isRecording { recordedLocations.append(location) }
    }

    private func handle(status: CLAuthorizationStatus) {
        authorizationStatus = status
        authContinuation?.resume(returning: status)
        authContinuation = nil
    }
}
