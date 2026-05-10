import SwiftUI
import CloudKit

struct CloudSharingView: UIViewControllerRepresentable {
    let league: League
    var onDone: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { _, completion in
            CloudKitManager.shared.prepareShare(for: league, completion: completion)
        }
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func itemTitle(for csc: UICloudSharingController) -> String? { nil }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { onDone() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { onDone() }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            onDone()
        }
    }
}
