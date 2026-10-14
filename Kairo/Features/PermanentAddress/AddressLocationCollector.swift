import CoreLocation
import UIKit

nonisolated enum AddressCollectionError: Error, LocalizedError, Equatable {
    case permission, disabled, unavailable, timeout, cancelled, policy
    var errorDescription: String? {
        switch self {
        case .permission: "Precise location is required. Enable Precise Location and While Using the App in iPhone Settings for KairoID, then try again."
        case .disabled: "Turn on Location Services, then try again."
        case .timeout: "Couldn't get an accurate location within 60 seconds. No successful check was added. Try again with a clearer view of the sky."
        case .cancelled: "Location collection stopped. Keep KairoID open with the screen on during a check."
        case .policy: "Location verification requirements changed. Refresh your status before trying again."
        case .unavailable: "Location verification isn't available on this device right now."
        }
    }
}

// Capture-quality constraints only. Never determines address match, target or verification.
nonisolated struct AddressSampleWindow {
    let started: Date
    let uptime: TimeInterval
    private(set) var priming: Date?
    private(set) var streamStarted: Date?
    private(set) var first: Date?
    private(set) var last: Date?
    private(set) var count = 0
    var complete: Bool { count >= 5 && (last?.timeIntervalSince(first ?? .distantFuture) ?? 0) >= 30 }
    func expired(nowUptime: TimeInterval) -> Bool { nowUptime - uptime >= 60 }
    mutating func accept(timestamp: Date, accuracy: Double, now: Date, nowUptime: TimeInterval) -> Bool {
        guard !expired(nowUptime: nowUptime), nowUptime >= uptime,
              abs(now.timeIntervalSince(started) - (nowUptime - uptime)) <= 2,
              timestamp >= started, timestamp <= now, now.timeIntervalSince(timestamp) <= 3,
              accuracy.isFinite, accuracy > 0 else { return false }
        if priming == nil {
            priming = timestamp; streamStarted = now
            return false // The priming fix never contributes evidence.
        }
        guard timestamp > priming!, timestamp >= streamStarted!, accuracy <= 50, count < 10,
              last == nil || timestamp.timeIntervalSince(last!) >= 6 else { return false }
        if first == nil { first = timestamp }
        last = timestamp; count += 1
        return true
    }
}

@MainActor protocol AddressLocationCollecting: AnyObject {
    func ensurePermission() async throws
    func collect() async throws -> [AddressLocationSample]
    func cancel()
}

@MainActor final class CoreAddressLocationCollector: NSObject, AddressLocationCollecting, CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    private var permission: CheckedContinuation<Void, Error>?
    private var result: CheckedContinuation<[AddressLocationSample], Error>?
    private var window: AddressSampleWindow?
    private var samples: [AddressLocationSample] = []
    private var mockObserved = false
    private var deadline: Task<Void, Never>?
    private var lifecycleObserver: NSObjectProtocol?
    private var permissionDeadline: Task<Void, Never>?

    func ensurePermission() async throws {
        var granted = false
        defer { if !granted { cancel() } }
        guard CLLocationManager.locationServicesEnabled() else { throw AddressCollectionError.disabled }
        guard UIApplication.shared.applicationState == .active else { throw AddressCollectionError.cancelled }
        guard permission == nil, result == nil else { throw AddressCollectionError.unavailable }
        let manager = CLLocationManager()
        self.manager = manager
        manager.delegate = self
        if manager.authorizationStatus == .notDetermined {
            try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    permission = continuation
                    permissionDeadline = Task { [weak self] in
                        try? await Task.sleep(for: .seconds(60))
                        guard !Task.isCancelled else { return }
                        self?.finishPermission(.failure(AddressCollectionError.permission))
                    }
                    manager.requestWhenInUseAuthorization()
                }
            }, onCancel: { Task { @MainActor [weak self] in self?.cancel() } })
        }
        try Task.checkCancellation()
        guard [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus),
              manager.accuracyAuthorization == .fullAccuracy else { throw AddressCollectionError.permission }
        granted = true
    }
    func collect() async throws -> [AddressLocationSample] {
        try Task.checkCancellation()
        guard let manager, result == nil, UIApplication.shared.applicationState == .active,
              CLLocationManager.locationServicesEnabled() else { throw AddressCollectionError.unavailable }
        guard [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus), manager.accuracyAuthorization == .fullAccuracy else { throw AddressCollectionError.permission }
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                result = continuation
                samples.removeAll(); mockObserved = false
                window = .init(started: Date(), uptime: ProcessInfo.processInfo.systemUptime)
                manager.desiredAccuracy = kCLLocationAccuracyBest
                manager.distanceFilter = kCLDistanceFilterNone
                manager.allowsBackgroundLocationUpdates = false
                lifecycleObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.finish(.failure(AddressCollectionError.cancelled)) }
                }
                deadline = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { return }
                    self?.finish(.failure(AddressCollectionError.timeout))
                }
                manager.requestLocation() // explicit new priming acquisition, never manager.location
            }
        }, onCancel: { Task { @MainActor [weak self] in self?.cancel() } })
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager === self.manager else { return }
        if manager.authorizationStatus == .notDetermined { return }
        let allowed = [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) && manager.accuracyAuthorization == .fullAccuracy
        if permission != nil { finishPermission(allowed ? .success(()) : .failure(AddressCollectionError.permission)) }
        if result != nil && !allowed { finish(.failure(AddressCollectionError.permission)) }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard manager === self.manager, result != nil else { return }
        guard UIApplication.shared.applicationState == .active else { finish(.failure(AddressCollectionError.cancelled)); return }
        for location in locations {
            guard CLLocationCoordinate2DIsValid(location.coordinate), location.coordinate.latitude.isFinite, location.coordinate.longitude.isFinite else { continue }
            mockObserved = mockObserved || location.sourceInformation?.isSimulatedBySoftware == true
            let wasPrimed = window?.priming != nil
            let accepted = window?.accept(timestamp: location.timestamp, accuracy: location.horizontalAccuracy,
                now: Date(), nowUptime: ProcessInfo.processInfo.systemUptime) == true
            if !wasPrimed && window?.priming != nil {
                manager.startUpdatingLocation()
                return // Exclude every other fix in the one-shot callback as well.
            }
            if accepted {
                samples.append(.init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                    accuracyM: location.horizontalAccuracy, timestamp: location.timestamp.ISO8601Format(.init(includingFractionalSeconds: true)), mockLocation: mockObserved))
            }
            if window?.complete == true {
                // If simulation was ever observed, preserve that fact for the entire evidence batch.
                let output = samples.map { AddressLocationSample(latitude: $0.latitude, longitude: $0.longitude, accuracyM: $0.accuracyM, timestamp: $0.timestamp, mockLocation: mockObserved) }
                finish(.success(output)); return
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard manager === self.manager else { return }
        if (error as? CLError)?.code == .locationUnknown, result != nil { return } // bounded by deadline
        finish(.failure(AddressCollectionError.unavailable))
    }
    func cancel() {
        finishPermission(.failure(AddressCollectionError.cancelled))
        finish(.failure(AddressCollectionError.cancelled))
    }
    private func finishPermission(_ value: Result<Void, Error>) {
        permissionDeadline?.cancel(); permissionDeadline = nil
        let continuation = permission; permission = nil; continuation?.resume(with: value)
    }
    private func finish(_ value: Result<[AddressLocationSample], Error>) {
        manager?.stopUpdatingLocation(); manager?.delegate = nil; manager = nil
        deadline?.cancel(); deadline = nil
        if let lifecycleObserver { NotificationCenter.default.removeObserver(lifecycleObserver) }
        lifecycleObserver = nil; window = nil; samples.removeAll(); mockObserved = false
        let continuation = result; result = nil; continuation?.resume(with: value)
    }
}

@MainActor final class AddressLocationOperation {
    private let collector: any AddressLocationCollecting
    private let service: any PermanentAddressServing
    private var challenge: AddressLocationChallenge?
    private var cancelled = false
    private var running = false
    private var submitting = false
    private var cancellationSent = false
    init(collector: any AddressLocationCollecting, service: any PermanentAddressServing) { self.collector = collector; self.service = service }
    func cancel() async {
        cancelled = true; collector.cancel()
        if !submitting { await cancelServer() }
    }
    private func cancelServer() async {
        guard let challenge, !cancellationSent else { return }
        cancellationSent = true
        // Cleanup must not inherit the cancelled collection task's cancellation.
        // Still exactly one best-effort cancel, never a replay of start/complete.
        let service = service
        await Task { try? await service.cancel(challenge) }.value
    }
    func run(version: String, stage: (String) -> Void) async throws -> PermanentAddressState {
        guard !running, !cancelled else { throw AddressCollectionError.cancelled }
        running = true
        var samples: [AddressLocationSample] = []
        do {
            stage("Waiting for precise-location permission...")
            try await collector.ensurePermission()
            guard !cancelled, !Task.isCancelled else { throw AddressCollectionError.cancelled }
            challenge = try await service.start(version: version)
            guard let challenge, !cancelled, !Task.isCancelled else { throw AddressCollectionError.cancelled }
            guard challenge.supported, challenge.expiresAt > Date() else { throw AddressCollectionError.policy }
            stage("Verifying your location. Keep KairoID open.")
            samples = try await collector.collect()
            collector.cancel() // Stop native services before any completion request.
            guard !cancelled, !Task.isCancelled, challenge.expiresAt > Date() else { throw AddressCollectionError.cancelled }
            stage("Collection stopped. Confirming the result with KairoID...")
            submitting = true
            let state = try await service.complete(challenge, samples: samples)
            samples.removeAll(); collector.cancel(); self.challenge = nil
            guard !cancelled else { throw AddressCollectionError.cancelled }
            return state
        } catch {
            samples.removeAll(); collector.cancel(); await cancelServer(); challenge = nil
            throw error
        }
    }
}
