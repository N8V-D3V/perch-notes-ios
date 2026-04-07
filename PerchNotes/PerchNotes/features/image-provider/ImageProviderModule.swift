//
//  ImageProviderModule.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
//

import CryptoKit
import Foundation

enum ImageAcquisitionMethod: String, Sendable {
    case CAPTURE_NEW_IMAGE
    case SELECT_EXISTING_IMAGE
}

enum CameraPermissionStateValue: String, Sendable {
    case GRANTED
    case DENIED
    case UNKNOWN
}

enum ImageAcquisitionStatus: String, Sendable {
    case SUCCESS
    case FAILED
}

enum ImageAcquisitionFailureReason: String, Sendable {
    case CAMERA_PERMISSION_REQUIRED
    case NO_IMAGE_ACQUIRED
    case MULTIPLE_IMAGES_NOT_SUPPORTED
    case IMAGE_ACQUISITION_CANCELLED
    case INVALID_SOURCE_IMAGE
    case IMAGE_ACQUISITION_FAILED
}

enum ImageAcquisitionResponseStatus: String, Sendable {
    case COMPLETED
    case CANCELLED
    case FAILED
}

struct ImageAcquisitionRequest: Sendable, Equatable {
    let acquisition_method: ImageAcquisitionMethod
}

struct CameraPermissionState: Sendable, Equatable {
    let state: CameraPermissionStateValue
}

struct ImageAcquisitionResponse: Sendable, Equatable {
    let status: ImageAcquisitionResponseStatus
    let image_count: Int
    let image_reference: String?
}

struct SourceImage: Sendable, Equatable {
    let image_id: String
    let origin_method: ImageAcquisitionMethod
    let image_reference: String
}

struct ImageAcquisitionResult: Sendable, Equatable {
    let status: ImageAcquisitionStatus
    let reason: ImageAcquisitionFailureReason?
}

protocol ImageProvider {
    func provideImage(
        image_acquisition_request: ImageAcquisitionRequest,
        camera_permission_state: CameraPermissionState
    ) -> (source_image: SourceImage?, image_acquisition_result: ImageAcquisitionResult)
}

protocol ImageAcquisitionResponding {
    func acquireImageResponse(for acquisitionMethod: ImageAcquisitionMethod) -> ImageAcquisitionResponse
}

struct ImageProviderModule: ImageProvider {
    enum Mode {
        case demoCompatible
        case responseDriven(any ImageAcquisitionResponding)
    }

    private let mode: Mode
    private let logHandler: (String) -> Void

    init(
        mode: Mode = .demoCompatible,
        logHandler: @escaping (String) -> Void = { print($0) }
    ) {
        self.mode = mode
        self.logHandler = logHandler
    }

    func provideImage(
        image_acquisition_request: ImageAcquisitionRequest,
        camera_permission_state: CameraPermissionState
    ) -> (source_image: SourceImage?, image_acquisition_result: ImageAcquisitionResult) {
        log(
            "input received: acquisition_method=\(image_acquisition_request.acquisition_method.rawValue), camera_permission_state=\(camera_permission_state.state.rawValue), mode=\(describeMode())"
        )

        if image_acquisition_request.acquisition_method == .CAPTURE_NEW_IMAGE,
           camera_permission_state.state != .GRANTED {
            log("decision path: camera capture requested without granted permission, returning CAMERA_PERMISSION_REQUIRED")
            let failure = ImageAcquisitionResult(status: .FAILED, reason: .CAMERA_PERMISSION_REQUIRED)
            log("output produced: source_image=nil, image_acquisition_result=\(describe(failure))")
            return (nil, failure)
        }

        log("intended behavior: acquire exactly one image response for the requested method, validate it, and convert it into one SourceImage")
        let acquisitionResponse = acquisitionResponder().acquireImageResponse(
            for: image_acquisition_request.acquisition_method
        )
        log("acquisition response received: \(describe(acquisitionResponse))")

        switch acquisitionResponse.status {
        case .CANCELLED:
            log("decision path: acquisition was cancelled by the user")
            let failure = ImageAcquisitionResult(status: .FAILED, reason: .IMAGE_ACQUISITION_CANCELLED)
            log("output produced: source_image=nil, image_acquisition_result=\(describe(failure))")
            return (nil, failure)

        case .FAILED:
            log("decision path: acquisition adapter reported failure before a valid image was returned")
            let failure = ImageAcquisitionResult(status: .FAILED, reason: .IMAGE_ACQUISITION_FAILED)
            log("output produced: source_image=nil, image_acquisition_result=\(describe(failure))")
            return (nil, failure)

        case .COMPLETED:
            if acquisitionResponse.image_count == 0 {
                log("decision path: acquisition completed with zero images, returning NO_IMAGE_ACQUIRED")
                let failure = ImageAcquisitionResult(status: .FAILED, reason: .NO_IMAGE_ACQUIRED)
                log("output produced: source_image=nil, image_acquisition_result=\(describe(failure))")
                return (nil, failure)
            }

            if acquisitionResponse.image_count > 1 {
                log("decision path: acquisition completed with more than one image, returning MULTIPLE_IMAGES_NOT_SUPPORTED")
                let failure = ImageAcquisitionResult(status: .FAILED, reason: .MULTIPLE_IMAGES_NOT_SUPPORTED)
                log("output produced: source_image=nil, image_acquisition_result=\(describe(failure))")
                return (nil, failure)
            }

            guard let validatedReference = validatedImageReference(from: acquisitionResponse.image_reference) else {
                log("decision path: acquisition completed without a valid image reference, returning INVALID_SOURCE_IMAGE")
                let failure = ImageAcquisitionResult(status: .FAILED, reason: .INVALID_SOURCE_IMAGE)
                log("output produced: source_image=nil, image_acquisition_result=\(describe(failure))")
                return (nil, failure)
            }

            guard let stableImageID = makeStableImageID(from: validatedReference) else {
                log("decision path: image reference could not be converted into a stable identifier, returning INVALID_SOURCE_IMAGE")
                let failure = ImageAcquisitionResult(status: .FAILED, reason: .INVALID_SOURCE_IMAGE)
                log("output produced: source_image=nil, image_acquisition_result=\(describe(failure))")
                return (nil, failure)
            }

            let sourceImage = SourceImage(
                image_id: stableImageID,
                origin_method: image_acquisition_request.acquisition_method,
                image_reference: validatedReference
            )
            let success = ImageAcquisitionResult(status: .SUCCESS, reason: nil)

            log("decision path: acquisition response converted into one valid source image")
            log("output produced: source_image=\(describe(sourceImage)), image_acquisition_result=\(describe(success))")
            return (sourceImage, success)
        }
    }

    private func acquisitionResponder() -> any ImageAcquisitionResponding {
        switch mode {
        case .demoCompatible:
            return DemoCompatibleImageAcquisitionResponder()
        case .responseDriven(let responder):
            return responder
        }
    }

    private func validatedImageReference(from imageReference: String?) -> String? {
        guard let imageReference else {
            return nil
        }

        let trimmedReference = imageReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedReference.isEmpty == false else {
            return nil
        }

        if demoCompatibleImageID(for: trimmedReference) != nil {
            return trimmedReference
        }

        if let url = URL(string: trimmedReference), url.isFileURL {
            return FileManager.default.fileExists(atPath: url.path) ? trimmedReference : nil
        }

        let fileURL = URL(fileURLWithPath: trimmedReference)
        return FileManager.default.fileExists(atPath: fileURL.path) ? trimmedReference : nil
    }

    private func makeStableImageID(from imageReference: String) -> String? {
        if let demoImageID = demoCompatibleImageID(for: imageReference) {
            return demoImageID
        }

        guard let imageData = loadImageData(from: imageReference) else {
            return nil
        }

        let digest = SHA256.hash(data: imageData)
        return "image-\(digest.map { String(format: "%02x", $0) }.joined())"
    }

    private func loadImageData(from imageReference: String) -> Data? {
        if let url = URL(string: imageReference), url.isFileURL {
            return try? Data(contentsOf: url)
        }

        let fileURL = URL(fileURLWithPath: imageReference)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return try? Data(contentsOf: fileURL)
    }

    private func demoCompatibleImageID(for imageReference: String) -> String? {
        switch imageReference {
        case "stub://image/capture-new-image":
            return "stub-image-capture-new-image"
        case "stub://image/select-existing-image":
            return "stub-image-select-existing-image"
        default:
            return nil
        }
    }

    private func describeMode() -> String {
        switch mode {
        case .demoCompatible:
            return "demoCompatible"
        case .responseDriven:
            return "responseDriven"
        }
    }

    private func describe(_ sourceImage: SourceImage) -> String {
        "SourceImage(image_id: \(sourceImage.image_id), origin_method: \(sourceImage.origin_method.rawValue), image_reference: \(sourceImage.image_reference))"
    }

    private func describe(_ result: ImageAcquisitionResult) -> String {
        "ImageAcquisitionResult(status: \(result.status.rawValue), reason: \(result.reason?.rawValue ?? "nil"))"
    }

    private func describe(_ response: ImageAcquisitionResponse) -> String {
        "ImageAcquisitionResponse(status: \(response.status.rawValue), image_count: \(response.image_count), image_reference: \(response.image_reference ?? "nil"))"
    }

    private func log(_ message: String) {
        logHandler("[ImageProviderModule] \(message)")
    }
}

private struct DemoCompatibleImageAcquisitionResponder: ImageAcquisitionResponding {
    func acquireImageResponse(for acquisitionMethod: ImageAcquisitionMethod) -> ImageAcquisitionResponse {
        switch acquisitionMethod {
        case .CAPTURE_NEW_IMAGE:
            return ImageAcquisitionResponse(
                status: .COMPLETED,
                image_count: 1,
                image_reference: "stub://image/capture-new-image"
            )

        case .SELECT_EXISTING_IMAGE:
            return ImageAcquisitionResponse(
                status: .COMPLETED,
                image_count: 1,
                image_reference: "stub://image/select-existing-image"
            )
        }
    }
}
