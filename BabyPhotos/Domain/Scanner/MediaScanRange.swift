import Foundation

/// Computes the effective lower bound date for media scanning.
/// Matches Android's `computeEffectiveMediaScanLowerBound` logic exactly.
///
/// - Parameters:
///   - configuredStart: The user-configured scan start date (must not be nil)
///   - snapshotAtLastScan: The configured start date snapshot taken at the last scan
///   - watermark: The dateAdded watermark from the last successful scan
/// - Returns: The effective lower bound date for scanning
func computeEffectiveMediaScanLowerBound(
    configuredStart: Date,
    snapshotAtLastScan: Date?,
    watermark: Date?
) -> Date {
    // If user changed settings (or first scan), use configured start
    if let snapshot = snapshotAtLastScan,
       snapshot == configuredStart,
       let watermark = watermark {
        // Incremental: resume from max of configured and watermark
        return max(configuredStart, watermark)
    }
    // First scan or user changed start date
    return configuredStart
}
