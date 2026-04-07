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
        let lineCandidates = detectLineSupports(in: image)

        guard lineCandidates.isEmpty == false else {
            return .failure(.NO_VALID_POWERLINE)
        }

        let validPowerlines = lineCandidates.compactMap { lineSupport in
            makeDetectedPowerline(from: lineSupport, among: components, image: image)
        }

        guard validPowerlines.isEmpty == false else {
            return .failure(.NO_BIRDS_DETECTED)
        }

        return .success(validPowerlines)
    }

    private func detectLineSupports(in image: GrayscaleImage) -> [DetectedLineSupport] {
        let lineThreshold: UInt8 = 150
        let interceptBinSize = 3.0
        let minimumSpan = max(28.0, Double(image.width) * 0.35)
        let minimumSupport = max(18, image.width / 10)
        let maximumCandidates = 16
        let slopes = stride(from: -0.35, through: 0.35, by: 0.025).map { value in
            Double(round(value * 1_000) / 1_000)
        }

        var accumulators: [LineAccumulatorKey: LineAccumulator] = [:]

        for y in 0..<image.height {
            for x in 0..<image.width {
                guard image.isDark(x: x, y: y, threshold: lineThreshold),
                      image.hasNearbyDarkPixel(x: x, y: y, threshold: lineThreshold) else {
                    continue
                }

                let darkness = Double(255 - image.intensity(x: x, y: y))
                for slope in slopes {
                    let intercept = Double(y) - (slope * Double(x))
                    let quantizedIntercept = Int((intercept / interceptBinSize).rounded())
                    let key = LineAccumulatorKey(slope: slope, interceptBin: quantizedIntercept)
                    var accumulator = accumulators[key] ?? LineAccumulator(slope: slope, interceptBin: quantizedIntercept)
                    accumulator.include(x: x, y: y, darkness: darkness)
                    accumulators[key] = accumulator
                }
            }
        }

        let rawSupports = accumulators.values.compactMap { accumulator -> DetectedLineSupport? in
            let spanWidth = Double(accumulator.maxX - accumulator.minX)
            guard spanWidth >= minimumSpan,
                  accumulator.supportCount >= minimumSupport else {
                return nil
            }

            let intercept = Double(accumulator.interceptBin) * interceptBinSize
            let centerX = (Double(accumulator.minX) + Double(accumulator.maxX)) / 2.0
            let centerY = (accumulator.slope * centerX) + intercept
            let averageDarkness = accumulator.darknessTotal / Double(accumulator.supportCount)
            let supportScore =
                (spanWidth * 120.0)
                + (Double(accumulator.supportCount) * 14.0)
                + averageDarkness

            return DetectedLineSupport(
                slope: accumulator.slope,
                intercept: intercept,
                minX: accumulator.minX,
                maxX: accumulator.maxX,
                centerY: centerY,
                supportCount: accumulator.supportCount,
                supportScore: supportScore
            )
        }

        let sortedSupports = rawSupports.sorted { lhs, rhs in
            if abs(lhs.supportScore - rhs.supportScore) >= 0.0001 {
                return lhs.supportScore > rhs.supportScore
            }

            if lhs.supportCount != rhs.supportCount {
                return lhs.supportCount > rhs.supportCount
            }

            if abs(lhs.spanWidth - rhs.spanWidth) >= 0.0001 {
                return lhs.spanWidth > rhs.spanWidth
            }

            if abs(lhs.slope - rhs.slope) >= 0.0001 {
                return abs(lhs.slope) < abs(rhs.slope)
            }

            return lhs.centerY < rhs.centerY
        }

        var deduplicatedSupports: [DetectedLineSupport] = []
        for support in sortedSupports {
            let isDuplicate = deduplicatedSupports.contains { existing in
                abs(existing.slope - support.slope) < 0.05
                    && abs(existing.intercept - support.intercept) < 10.0
            }

            if isDuplicate == false {
                deduplicatedSupports.append(support)
            }

            if deduplicatedSupports.count == maximumCandidates {
                break
            }
        }

        return deduplicatedSupports
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
        from lineSupport: DetectedLineSupport,
        among allComponents: [ConnectedComponent],
        image: GrayscaleImage
    ) -> DetectedPowerline? {
        let verticalBirdDistance = max(14.0, Double(image.height) * 0.14)
        let maximumBirdWidth = max(8, image.width / 6)
        let maximumBirdHeight = max(8, image.height / 5)
        let horizontalPadding = max(10.0, Double(image.width) * 0.03)

        let birdComponents = allComponents.filter { component in
            guard component.area >= 8,
                  component.width >= 2,
                  component.height >= 2,
                  component.width <= maximumBirdWidth,
                  component.height <= maximumBirdHeight,
                  component.width <= (component.height * 2) + 2 else {
                return false
            }

            guard component.centerX >= Double(lineSupport.minX) - horizontalPadding,
                  component.centerX <= Double(lineSupport.maxX) + horizontalPadding else {
                return false
            }

            let predictedLineY = lineSupport.yPosition(atX: component.centerX)
            let verticalDistance = abs(component.centerY - predictedLineY)
            guard verticalDistance <= verticalBirdDistance else {
                return false
            }

            return component.width < Int(max(10.0, lineSupport.spanWidth * 0.35))
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

        let averageBirdDistance =
            birdComponents
            .map { component in abs(component.centerY - lineSupport.yPosition(atX: component.centerX)) }
            .reduce(0.0, +) / Double(birdComponents.count)
        let verticalCenter = Double(image.height) / 2.0
        let centralityScore = max(0.0, 1.0 - (abs(lineSupport.centerY - verticalCenter) / max(verticalCenter, 1.0)))
        let prominenceScore =
            (Double(birds.count) * 100_000.0)
            + (lineSupport.spanWidth * 200.0)
            + (Double(lineSupport.supportCount) * 20.0)
            + (centralityScore * 10.0)
            - (averageBirdDistance * 50.0)
            + lineSupport.supportScore

        return DetectedPowerline(
            centerY: lineSupport.centerY,
            prominenceScore: prominenceScore,
            birds: birds,
            slope: lineSupport.slope,
            spanWidth: lineSupport.spanWidth,
            supportCount: lineSupport.supportCount,
            averageBirdDistance: averageBirdDistance,
            centralityScore: centralityScore
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

    func hasNearbyDarkPixel(x: Int, y: Int, threshold: UInt8) -> Bool {
        for neighborY in max(0, y - 1)...min(height - 1, y + 1) {
            for neighborX in max(0, x - 2)...min(width - 1, x + 2) {
                guard neighborX != x || neighborY != y else {
                    continue
                }

                if isDark(x: neighborX, y: neighborY, threshold: threshold) {
                    return true
                }
            }
        }

        return false
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

private struct LineAccumulatorKey: Hashable {
    let slope: Double
    let interceptBin: Int
}

private struct LineAccumulator {
    let slope: Double
    let interceptBin: Int
    private(set) var minX: Int = .max
    private(set) var maxX: Int = .min
    private(set) var minY: Int = .max
    private(set) var maxY: Int = .min
    private(set) var supportCount: Int = 0
    private(set) var darknessTotal: Double = 0

    mutating func include(x: Int, y: Int, darkness: Double) {
        minX = Swift.min(minX, x)
        maxX = Swift.max(maxX, x)
        minY = Swift.min(minY, y)
        maxY = Swift.max(maxY, y)
        supportCount += 1
        darknessTotal += darkness
    }
}

private struct DetectedLineSupport {
    let slope: Double
    let intercept: Double
    let minX: Int
    let maxX: Int
    let centerY: Double
    let supportCount: Int
    let supportScore: Double

    var spanWidth: Double {
        Double(maxX - minX)
    }

    func yPosition(atX x: Double) -> Double {
        (slope * x) + intercept
    }
}
