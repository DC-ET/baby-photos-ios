import Foundation
@preconcurrency import Photos

enum PhotoPermissionHelper {
    static func currentAuthorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func hasFullAccess() -> Bool {
        let status = currentAuthorizationStatus()
        return status == .authorized || status == .limited
    }

    static func requestFullAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
}
