import ReplayKit
import LiveKit

final class SampleHandler: LKSampleHandler, @unchecked Sendable {
    // LKSampleHandler handles the broadcast lifecycle automatically.
    // Ensure your App Group is correctly configured in your Entitlements.
}