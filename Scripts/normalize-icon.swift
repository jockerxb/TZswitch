import Foundation
import CoreGraphics
import ImageIO

enum IconError: Error { case invalidImage, transparentCenter, outputFailure, invalidArguments }

struct Artwork {
    let image: CGImage
    let pixels: [UInt8]
    let width: Int
    let height: Int

    init(_ path: String) throws {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let original = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw IconError.invalidImage }
        let pixelWidth = original.width
        let pixelHeight = original.height
        width = pixelWidth
        height = pixelHeight
        var buffer = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        let result: CGImage? = buffer.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: pixelWidth, height: pixelHeight,
                bitsPerComponent: 8, bytesPerRow: pixelWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
            context.draw(original, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            return context.makeImage()
        }
        guard let result else { throw IconError.invalidImage }
        image = result
        pixels = buffer
    }

    func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * width + x) * 4 + 3] }

    // A rounded-square app tile has straight opaque edges through its center.
    // Using these edges avoids counting isolated alpha specks in generated art.
    func bodyBounds(threshold: UInt8 = 250) throws -> CGRect {
        let cx = width / 2, cy = height / 2
        guard alpha(cx, cy) >= threshold else { throw IconError.transparentCenter }
        var left = cx, right = cx, top = cy, bottom = cy
        while left > 0 && alpha(left - 1, cy) >= threshold { left -= 1 }
        while right + 1 < width && alpha(right + 1, cy) >= threshold { right += 1 }
        while top > 0 && alpha(cx, top - 1) >= threshold { top -= 1 }
        while bottom + 1 < height && alpha(cx, bottom + 1) >= threshold { bottom += 1 }
        return CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }

    func report() throws -> [String: Any] {
        let bounds = try bodyBounds()
        let visible = try bodyBounds(threshold: 128)
        return ["canvasWidth": width, "canvasHeight": height,
                "bodyX": Int(bounds.minX), "bodyY": Int(bounds.minY),
                "bodyWidth": Int(bounds.width), "bodyHeight": Int(bounds.height),
                "bodyRatio": max(bounds.width / CGFloat(width), bounds.height / CGFloat(height)),
                "visibleBodyX": Int(visible.minX), "visibleBodyY": Int(visible.minY),
                "visibleBodyWidth": Int(visible.width), "visibleBodyHeight": Int(visible.height),
                "cornerAlpha": Int(alpha(0, 0)), "centerAlpha": Int(alpha(width / 2, height / 2))]
    }
}

func normalize(_ input: String, _ output: String, canvas: Int = 1024) throws {
    guard canvas > 0, canvas <= 1024 else { throw IconError.invalidArguments }
    let artwork = try Artwork(input)
    let bounds = try artwork.bodyBounds()
    // Classic macOS icon grid (for this macOS 15 ICNS app): an 824 px body
    // centered on a 1024 px transparent canvas, with 100 px optical margins.
    let body = Int((Double(canvas) * 824 / 1024).rounded())
    let margin = CGFloat(canvas - body) / 2
    let side = max(bounds.width, bounds.height)
    let crop = CGRect(x: floor(bounds.midX - side / 2), y: floor(bounds.midY - side / 2), width: side, height: side)
    guard let cropped = artwork.image.cropping(to: crop),
          let context = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8,
                bytesPerRow: canvas * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { throw IconError.outputFailure }
    context.clear(CGRect(x: 0, y: 0, width: canvas, height: canvas))
    let tile = CGRect(x: margin, y: margin, width: CGFloat(body), height: CGFloat(body))
    let radius = CGFloat(body) * 0.223
    context.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    // The approved artwork is composited onto an opaque native-size tile.
    // This keeps antialiased source alpha from shrinking small representations.
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(tile)
    context.interpolationQuality = .high
    context.draw(cropped, in: tile)
    guard let result = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, "public.png" as CFString, 1, nil) else { throw IconError.outputFailure }
    CGImageDestinationAddImage(destination, result, [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw IconError.outputFailure }
}

do {
    let args = CommandLine.arguments
    guard args.count >= 3 else { throw IconError.invalidArguments }
    if args[1] == "normalize", args.count == 4 { try normalize(args[2], args[3]) }
    else if args[1] == "resize", args.count == 5, let size = Int(args[4]) { try normalize(args[2], args[3], canvas: size) }
    else if args[1] != "inspect" { throw IconError.invalidArguments }
    let path = args[1] == "inspect" ? args[2] : args[3]
    let json = try JSONSerialization.data(withJSONObject: Artwork(path).report(), options: [.sortedKeys])
    print(String(decoding: json, as: UTF8.self))
} catch {
    FileHandle.standardError.write(Data("图标尺寸处理失败：\(error)\n".utf8))
    exit(1)
}
