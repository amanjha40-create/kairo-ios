import XCTest
import SwiftUI
import UIKit
@testable import Kairo

@MainActor final class KairoLogoTransparencyTests: XCTestCase {
    func testMasterPreservesCanvasNavyTealSymbolAndTMWithTrueAlpha() throws {
        let image = try XCTUnwrap(UIImage(named: "KairoIDMaster")?.cgImage)
        XCTAssertEqual(image.width, 1280)
        XCTAssertEqual(image.height, 428)
        let pixels = try rgba(image)
        let samples: [(Int, Int, [UInt8])] = [
            (470, 180, [15, 50, 92, 255]), // Kairo navy
            (1010, 180, [3, 164, 164, 255]), // ID teal
            (1198, 138, [6, 47, 93, 255]), // original TM
            (220, 110, [1, 170, 171, 255]) // original symbol gradient
        ]
        for (x, y, expected) in samples {
            let index = (y * image.width + x) * 4
            for c in 0..<4 {
                XCTAssertEqual(Int(pixels[index+c]), Int(expected[c]), accuracy: 2)
            }
        }
        let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        XCTAssertGreaterThan(alpha.filter { $0 == 0 }.count, image.width * image.height * 3 / 4)
        XCTAssertGreaterThan(alpha.filter { $0 > 0 && $0 < 255 }.count, 1000)
        XCTAssertEqual(pixels[3], 0)
        XCTAssertEqual(pixels[pixels.count-1], 0)
    }

    func testSharedLogoRendersWithoutOpaqueRectangleInBothThemes() throws {
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: KairoIDBrandView(width: 108)
                .frame(width: 108, height: 108 * 428 / 1280)
                .environment(\.colorScheme, scheme))
            renderer.scale = 3
            renderer.isOpaque = false
            let image = try XCTUnwrap(renderer.cgImage)
            let pixels = try rgba(image)
            let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
            XCTAssertGreaterThan(alpha.filter { $0 == 0 }.count, alpha.count / 2)
            XCTAssertLessThan(alpha.filter { $0 > 240 }.count, alpha.count / 2)
            XCTAssertEqual(pixels[3], 0)
            XCTAssertEqual(pixels[pixels.count-1], 0)
        }
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { raw in
            let context = try XCTUnwrap(CGContext(data: raw.baseAddress, width: image.width,
                height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }
}
