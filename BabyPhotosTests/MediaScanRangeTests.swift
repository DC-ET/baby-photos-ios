import Testing
import Foundation
@testable import BabyPhotos

@Suite("MediaScanRange Tests")
struct MediaScanRangeTests {
    @Test("First scan or user changed start uses configured only")
    func firstScanOrUserChangedStart_usesConfiguredOnly() {
        let configured = Date(timeIntervalSince1970: 1000)
        let snapshot: Date? = nil  // no previous scan
        let watermark: Date? = nil

        let result = computeEffectiveMediaScanLowerBound(
            configuredStart: configured,
            snapshotAtLastScan: snapshot,
            watermark: watermark
        )

        #expect(result == configured)
    }

    @Test("User changed start date uses configured only")
    func userChangedStart_usesConfiguredOnly() {
        let configured = Date(timeIntervalSince1970: 2000)
        let snapshot = Date(timeIntervalSince1970: 1000)  // different from configured
        let watermark = Date(timeIntervalSince1970: 1500)

        let result = computeEffectiveMediaScanLowerBound(
            configuredStart: configured,
            snapshotAtLastScan: snapshot,
            watermark: watermark
        )

        #expect(result == configured)
    }

    @Test("Incremental scan uses max of configured and watermark")
    func incremental_usesMaxOfConfiguredAndWatermark() {
        let configured = Date(timeIntervalSince1970: 1000)
        let snapshot = Date(timeIntervalSince1970: 1000)  // same as configured
        let watermark = Date(timeIntervalSince1970: 1500)

        let result = computeEffectiveMediaScanLowerBound(
            configuredStart: configured,
            snapshotAtLastScan: snapshot,
            watermark: watermark
        )

        #expect(result == watermark)
    }

    @Test("Incremental scan with watermark before configured uses configured")
    func incremental_watermarkBeforeConfigured_usesConfigured() {
        let configured = Date(timeIntervalSince1970: 2000)
        let snapshot = Date(timeIntervalSince1970: 2000)  // same as configured
        let watermark = Date(timeIntervalSince1970: 1000)

        let result = computeEffectiveMediaScanLowerBound(
            configuredStart: configured,
            snapshotAtLastScan: snapshot,
            watermark: watermark
        )

        #expect(result == configured)
    }
}
