//
//  ImageProviderModule.swift
//  PerchNotes
//
//  Created by Codex on 4/6/26.
//

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

struct ImageAcquisitionRequest: Sendable, Equatable {
    let acquisition_method: ImageAcquisitionMethod
}

struct CameraPermissionState: Sendable, Equatable {
    let state: CameraPermissionStateValue
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

struct ImageProviderModule: ImageProvider {
    private let logHandler: (String) -> Void

    init(logHandler: @escaping (String) -> Void = { print($0) }) {
        self.logHandler = logHandler
    }

    func provideImage(
        image_acquisition_request: ImageAcquisitionRequest,
        camera_permission_state: CameraPermissionState
    ) -> (source_image: SourceImage?, image_acquisition_result: ImageAcquisitionResult) {
        log("input received: acquisition_method=\(image_acquisition_request.acquisition_method.rawValue), camera_permission_state=\(camera_permission_state.state.rawValue)")

        if image_acquisition_request.acquisition_method == .CAPTURE_NEW_IMAGE,
           camera_permission_state.state != .GRANTED {
            log("decision path: camera capture requested without granted permission, returning CAMERA_PERMISSION_REQUIRED")
            let failure = ImageAcquisitionResult(status: .FAILED, reason: .CAMERA_PERMISSION_REQUIRED)
            log("output produced: source_image=nil, image_acquisition_result=\(describe(failure))")
            return (nil, failure)
        }

        log("intended behavior: acquire exactly one source image using the requested method without performing real camera or photo-library work")

        let source_image = SourceImage(
            image_id: deterministicImageID(for: image_acquisition_request.acquisition_method),
            origin_method: image_acquisition_request.acquisition_method,
            image_reference: deterministicImageReference(for: image_acquisition_request.acquisition_method)
        )
        let success = ImageAcquisitionResult(status: .SUCCESS, reason: nil)

        log("decision path: stub acquisition succeeded with one simulated image artifact")
        log("output produced: source_image=\(describe(source_image)), image_acquisition_result=\(describe(success))")
        return (source_image, success)
    }

    private func deterministicImageID(for acquisitionMethod: ImageAcquisitionMethod) -> String {
        switch acquisitionMethod {
        case .CAPTURE_NEW_IMAGE:
            return "stub-image-capture-new-image"
        case .SELECT_EXISTING_IMAGE:
            return "stub-image-select-existing-image"
        }
    }

    private func deterministicImageReference(for acquisitionMethod: ImageAcquisitionMethod) -> String {
        switch acquisitionMethod {
        case .CAPTURE_NEW_IMAGE:
            return "stub://image/capture-new-image"
        case .SELECT_EXISTING_IMAGE:
            return "stub://image/select-existing-image"
        }
    }

    private func describe(_ sourceImage: SourceImage) -> String {
        "SourceImage(image_id: \(sourceImage.image_id), origin_method: \(sourceImage.origin_method.rawValue), image_reference: \(sourceImage.image_reference))"
    }

    private func describe(_ result: ImageAcquisitionResult) -> String {
        "ImageAcquisitionResult(status: \(result.status.rawValue), reason: \(result.reason?.rawValue ?? "nil"))"
    }

    private func log(_ message: String) {
        logHandler("[ImageProviderModule] \(message)")
    }
}
