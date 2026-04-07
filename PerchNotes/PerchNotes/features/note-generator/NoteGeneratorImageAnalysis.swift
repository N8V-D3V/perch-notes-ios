//
//  NoteGeneratorImageAnalysis.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
//

import CoreGraphics
import Foundation
import ImageIO

struct LocalImageNoteAnalyzer: NoteImageAnalyzing {
    func analyze(source_image: SourceImage) -> NoteImageAnalysisResult {
        guard let image = GrayscaleImage.load(from: source_image.image_reference) else {
            return .failure(.IMAGE_ANALYSIS_FAILED)
        }

        guard image.width >= 24, image.height >= 24 else {
            return .failure(.IMAGE_ANALYSIS_FAILED)
        }

        let components = detectConnectedComponents(in: image)
        let lineCandidates = components.filter { component in
            component.width >= max(18, Int(Double(image.width) * 0.25))
                && component.height <= max(6, image.height / 12)
        }

        guard lineCandidates.isEmpty == false else {
            return .failure(.NO_VALID_POWERLINE)
        }

        let validPowerlines = lineCandidates.compactMap { lineComponent in
            makeDetectedPowerline(from: lineComponent, among: components, image: image)
        }

        guard validPowerlines.isEmpty == false else {
            return .failure(.NO_BIRDS_DETECTED)
        }

        return .success(validPowerlines)
    }

    private func detectConnectedComponents(in image: GrayscaleImage) -> [ConnectedComponent] {
        let darkThreshold: UInt8 = 125
        var visited = [Bool](repeating: false, count: image.width * image.height)
        var components: [ConnectedComponent] = []

        for y in 0..<image.height {
            for x in 0..<image.width {
                let index = (y * image.width) + x
                guard visited[index] == false else {
                    continue
                }

                visited[index] = true
                guard image.isDark(x: x, y: y, threshold: darkThreshold) else {
                    continue
                }

                var queue: [(x: Int, y: Int)] = [(x, y)]
                var cursor = 0
                var points: [(x: Int, y: Int)] = []
                points.reserveCapacity(32)

                while cursor < queue.count {
                    let point = queue[cursor]
                    cursor += 1
                    points.append(point)

                    for neighborY in max(0, point.y - 1)...min(image.height - 1, point.y + 1) {
                        for neighborX in max(0, point.x - 1)...min(image.width - 1, point.x + 1) {
                            let neighborIndex = (neighborY * image.width) + neighborX
                            guard visited[neighborIndex] == false else {
                                continue
                            }

                            visited[neighborIndex] = true
                            if image.isDark(x: neighborX, y: neighborY, threshold: darkThreshold) {
                                queue.append((neighborX, neighborY))
                            }
                        }
                    }
                }

                components.append(ConnectedComponent(points: points, image: image))
            }
        }

        return components
    }

    private func makeDetectedPowerline(
        from lineComponent: ConnectedComponent,
        among allComponents: [ConnectedComponent],
        image: GrayscaleImage
    ) -> DetectedPowerline? {
        let verticalBirdDistance = max(16, image.height / 4)
        let maximumBirdWidth = max(8, image.width / 6)
        let maximumBirdHeight = max(8, image.height / 5)

        let birdComponents = allComponents.filter { component in
            guard component.id != lineComponent.id else {
                return false
            }

            guard component.area >= 8,
                  component.width >= 2,
                  component.height >= 2,
                  component.width <= maximumBirdWidth,
                  component.height <= maximumBirdHeight else {
                return false
            }

            let verticalDistance = abs(component.centerY - lineComponent.centerY)
            guard verticalDistance <= Double(verticalBirdDistance) else {
                return false
            }

            return component.width < lineComponent.width
        }

        guard birdComponents.isEmpty == false else {
            return nil
        }

        let birds = birdComponents.map { component in
            DetectedBird(
                centerX: component.centerX,
                centerY: component.centerY,
                darknessScore: component.darknessScore
            )
        }

        let prominenceScore =
            (Double(birds.count) * 10_000.0)
            + (Double(lineComponent.width) * 100.0)
            + lineComponent.darknessScore

        return DetectedPowerline(
            centerY: lineComponent.centerY,
            prominenceScore: prominenceScore,
            birds: birds
        )
    }
}

private struct GrayscaleImage {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    static func load(from imageReference: String) -> GrayscaleImage? {
        guard let imageURL = resolvedURL(from: imageReference),
              let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let maximumWidth = min(image.width, 320)
        let scale = Double(maximumWidth) / Double(image.width)
        let targetWidth = max(1, maximumWidth)
        let targetHeight = max(1, Int((Double(image.height) * scale).rounded()))
        let bytesPerRow = targetWidth

        var pixels = [UInt8](repeating: 255, count: targetWidth * targetHeight)
        let rendered = pixels.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: targetWidth,
                    height: targetHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else {
                return false
            }

            context.interpolationQuality = .high
            context.setFillColor(gray: 1.0, alpha: 1.0)
            context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
            context.translateBy(x: 0, y: CGFloat(targetHeight))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
            return true
        }

        guard rendered else {
            return nil
        }

        return GrayscaleImage(width: targetWidth, height: targetHeight, pixels: pixels)
    }

    func intensity(x: Int, y: Int) -> UInt8 {
        pixels[(y * width) + x]
    }

    func isDark(x: Int, y: Int, threshold: UInt8) -> Bool {
        intensity(x: x, y: y) <= threshold
    }

    private static func resolvedURL(from imageReference: String) -> URL? {
        if let url = URL(string: imageReference), url.isFileURL {
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        let fileURL = URL(fileURLWithPath: imageReference)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}

private struct ConnectedComponent {
    let id: String
    let area: Int
    let width: Int
    let height: Int
    let centerX: Double
    let centerY: Double
    let darknessScore: Double

    init(points: [(x: Int, y: Int)], image: GrayscaleImage) {
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let weightedDarkness = points.reduce(0.0) { partial, point in
            partial + Double(255 - image.intensity(x: point.x, y: point.y))
        }
        let weightedX = points.reduce(0.0) { partial, point in
            partial + (Double(point.x) * Double(255 - image.intensity(x: point.x, y: point.y)))
        }
        let weightedY = points.reduce(0.0) { partial, point in
            partial + (Double(point.y) * Double(255 - image.intensity(x: point.x, y: point.y)))
        }

        self.id = "\(minX)-\(minY)-\(maxX)-\(maxY)-\(points.count)"
        self.area = points.count
        self.width = (maxX - minX) + 1
        self.height = (maxY - minY) + 1
        self.centerX = weightedDarkness == 0 ? Double(minX + maxX) / 2.0 : weightedX / weightedDarkness
        self.centerY = weightedDarkness == 0 ? Double(minY + maxY) / 2.0 : weightedY / weightedDarkness
        self.darknessScore = weightedDarkness
    }
}
