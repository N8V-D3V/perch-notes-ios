//
//  ImageProviderInteractiveAcquisition.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
//

import Foundation

#if os(iOS)
import SwiftUI
import UIKit

final class InteractiveImageAcquisitionResponder: ImageAcquisitionResponding {
    private let lock = NSLock()
    private var pendingResponses: [ImageAcquisitionMethod: ImageAcquisitionResponse] = [:]

    func acquireImageResponse(for acquisitionMethod: ImageAcquisitionMethod) -> ImageAcquisitionResponse {
        lock.lock()
        defer { lock.unlock() }

        return pendingResponses.removeValue(forKey: acquisitionMethod)
            ?? ImageAcquisitionResponse(status: .FAILED, image_count: 0, image_reference: nil)
    }

    func recordCompletedImage(_ image: UIImage, for acquisitionMethod: ImageAcquisitionMethod) {
        do {
            let imageReference = try persistImage(image, for: acquisitionMethod)
            store(
                ImageAcquisitionResponse(
                    status: .COMPLETED,
                    image_count: 1,
                    image_reference: imageReference
                ),
                for: acquisitionMethod
            )
        } catch {
            store(
                ImageAcquisitionResponse(
                    status: .FAILED,
                    image_count: 0,
                    image_reference: nil
                ),
                for: acquisitionMethod
            )
        }
    }

    func recordCancelled(for acquisitionMethod: ImageAcquisitionMethod) {
        store(
            ImageAcquisitionResponse(
                status: .CANCELLED,
                image_count: 0,
                image_reference: nil
            ),
            for: acquisitionMethod
        )
    }

    func recordFailure(for acquisitionMethod: ImageAcquisitionMethod) {
        store(
            ImageAcquisitionResponse(
                status: .FAILED,
                image_count: 0,
                image_reference: nil
            ),
            for: acquisitionMethod
        )
    }

    private func store(_ response: ImageAcquisitionResponse, for acquisitionMethod: ImageAcquisitionMethod) {
        lock.lock()
        pendingResponses[acquisitionMethod] = response
        lock.unlock()
    }

    private func persistImage(_ image: UIImage, for acquisitionMethod: ImageAcquisitionMethod) throws -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("perch-notes-image-provider", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = "\(acquisitionMethod.rawValue.lowercased())-\(UUID().uuidString).jpg"
        let fileURL = directory.appendingPathComponent(fileName)

        if let jpegData = image.jpegData(compressionQuality: 0.92) {
            try jpegData.write(to: fileURL, options: .atomic)
            return fileURL.absoluteString
        }

        guard let pngData = image.pngData() else {
            throw InteractiveImageAcquisitionError.unsupportedImageData
        }

        let pngURL = directory.appendingPathComponent(fileName.replacingOccurrences(of: ".jpg", with: ".png"))
        try pngData.write(to: pngURL, options: .atomic)
        return pngURL.absoluteString
    }
}

struct ImageProviderAcquisitionSheet: UIViewControllerRepresentable {
    let acquisitionMethod: ImageAcquisitionMethod
    let responder: InteractiveImageAcquisitionResponder
    let onComplete: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            acquisitionMethod: acquisitionMethod,
            responder: responder,
            onComplete: onComplete
        )
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        switch acquisitionMethod {
        case .CAPTURE_NEW_IMAGE:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                responder.recordFailure(for: acquisitionMethod)
                return picker
            }
            picker.sourceType = .camera

        case .SELECT_EXISTING_IMAGE:
            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
                responder.recordFailure(for: acquisitionMethod)
                return picker
            }
            picker.sourceType = .photoLibrary
        }

        picker.mediaTypes = ["public.image"]
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let acquisitionMethod: ImageAcquisitionMethod
        private let responder: InteractiveImageAcquisitionResponder
        private let onComplete: () -> Void

        init(
            acquisitionMethod: ImageAcquisitionMethod,
            responder: InteractiveImageAcquisitionResponder,
            onComplete: @escaping () -> Void
        ) {
            self.acquisitionMethod = acquisitionMethod
            self.responder = responder
            self.onComplete = onComplete
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            responder.recordCancelled(for: acquisitionMethod)
            picker.dismiss(animated: true) { [onComplete] in
                onComplete()
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage

            guard let image else {
                responder.recordFailure(for: acquisitionMethod)
                picker.dismiss(animated: true) { [onComplete] in
                    onComplete()
                }
                return
            }

            responder.recordCompletedImage(image, for: acquisitionMethod)
            picker.dismiss(animated: true) { [onComplete] in
                onComplete()
            }
        }
    }
}

private enum InteractiveImageAcquisitionError: Error {
    case unsupportedImageData
}
#endif
