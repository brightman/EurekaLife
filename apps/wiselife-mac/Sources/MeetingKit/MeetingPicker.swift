import Foundation
import ScreenCaptureKit

@MainActor public final class MeetingPicker: NSObject, SCContentSharingPickerObserver {
    private var continuation: CheckedContinuation<SCContentFilter?, Error>?
    public override init() { super.init() }
    public func choose() async throws -> SCContentFilter? {
        guard continuation == nil else { throw MeetingFailure.message("画面选择器已打开。") }
        let picker = SCContentSharingPicker.shared
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleDisplay, .singleWindow]
        configuration.allowsChangingSelectedContent = false
        picker.defaultConfiguration = configuration
        picker.maximumStreamCount = 1
        picker.add(self); picker.isActive = true
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            picker.present()
        }
    }
    public func dismiss() { complete(.success(nil)) }
    public func deactivate() {
        SCContentSharingPicker.shared.remove(self)
        SCContentSharingPicker.shared.isActive = false
    }
    private func complete(_ result: Result<SCContentFilter?, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        SCContentSharingPicker.shared.remove(self)
        if case .success(nil) = result { SCContentSharingPicker.shared.isActive = false }
        if case .failure = result { SCContentSharingPicker.shared.isActive = false }
        continuation.resume(with: result)
    }
    nonisolated public func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in self.complete(.success(nil)) }
    }
    nonisolated public func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in self.complete(.success(filter)) }
    }
    nonisolated public func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor in self.complete(.failure(error)) }
    }
}
