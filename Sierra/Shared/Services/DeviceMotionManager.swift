import Foundation
import CoreMotion

/// Reads device pitch via CoreMotion and maps it to a Mapbox map pitch value.
/// Used to let the driver tilt their phone to rotate the map perspective.
@MainActor
@Observable
final class DeviceMotionManager {

    static let shared = DeviceMotionManager()

    /// Map pitch in degrees (0 = top-down, 65 = max perspective).
    private(set) var mapPitch: CGFloat = 48

    /// Whether tilt control is currently active.
    private(set) var isActive = false

    // MARK: - Private
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var lastPublishedPitch: CGFloat = 48
    private let pitchDeadband: CGFloat = 2.0  // Only update if pitch changes by >2°
    private var lastUpdateTime: Date = .distantPast

    private init() {
        queue.name = "com.sierra.deviceMotion"
        queue.maxConcurrentOperationCount = 1
    }

    /// Start reading device pitch. Safe to call multiple times.
    func start() {
        guard motionManager.isDeviceMotionAvailable, !isActive else { return }
        isActive = true

        motionManager.deviceMotionUpdateInterval = 1.0 / 15 // 15 Hz
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: queue
        ) { [weak self] motion, _ in
            guard let motion, let self else { return }

            // pitch: radians, negative when tilted away from user
            // Portrait: pitch ~0 = flat on table, pitch ~-π/2 = held upright
            let pitchDeg = abs(motion.attitude.pitch * 180 / .pi)

            // Map: flat phone (0-20°) → bird's-eye (pitch 0-10)
            //       mid-tilt (20-60°) → normal nav (pitch 10-50)
            //       upright (60-90°) → full perspective (pitch 50-65)
            let mapped: CGFloat
            if pitchDeg < 20 {
                mapped = pitchDeg / 20 * 10       // 0-20° → 0-10
            } else if pitchDeg < 60 {
                mapped = 10 + (pitchDeg - 20) / 40 * 40  // 20-60° → 10-50
            } else {
                mapped = 50 + (min(pitchDeg, 90) - 60) / 30 * 15  // 60-90° → 50-65
            }

            // Throttle: only publish if change exceeds deadband AND minimum interval
            let now = Date()
            guard abs(mapped - self.lastPublishedPitch) > self.pitchDeadband,
                  now.timeIntervalSince(self.lastUpdateTime) > 0.25 else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastPublishedPitch = mapped
                self.lastUpdateTime = now
                self.mapPitch = mapped
            }
        }
    }

    /// Stop device motion updates.
    func stop() {
        guard isActive else { return }
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        mapPitch = 48  // Reset to default
    }
}
