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
            XCTAssertEqual(image.width, 324)
            if scheme == .dark {
                for i in stride(from: 0, to: pixels.count, by: 4) {
                    for channel in 0..<3 {
                        XCTAssertEqual(Int(pixels[i + channel]), Int(pixels[i + 3]), accuracy: 1)
                    }
                }
            }
        }
    }

    func testWhiteMasterPreservesEveryAlphaAndMakesSymbolWordmarkAndTMWhite() throws {
        let primary = try XCTUnwrap(UIImage(named: "KairoIDMaster")?.cgImage)
        let white = try XCTUnwrap(UIImage(named: "KairoIDMasterWhite")?.cgImage)
        XCTAssertEqual(white.width, primary.width)
        XCTAssertEqual(white.height, primary.height)
        let original = try rgba(primary)
        let pixels = try rgba(white)
        XCTAssertEqual(pixels.count, original.count)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            XCTAssertEqual(pixels[i + 3], original[i + 3], "Exact master alpha must survive")
            XCTAssertEqual(pixels[i], pixels[i + 1], "White cannot contain a color cast")
            XCTAssertEqual(pixels[i + 1], pixels[i + 2], "White cannot contain a color cast")
            for channel in 0..<3 {
                // CoreGraphics rounds compiled-asset premultiplication by up to one level.
                XCTAssertEqual(Int(pixels[i + channel]), Int(pixels[i + 3]), accuracy: 1)
            }
        }
        for (x, y) in [(470, 180), (1010, 180), (1198, 138), (220, 110)] {
            let index = (y * white.width + x) * 4
            XCTAssertEqual(Array(pixels[index..<index + 4]), [255, 255, 255, 255])
        }
    }

    func testThemeSelectionAndFixedLightArtworkOverride() throws {
        XCTAssertEqual(KairoIDBrandVariant.adaptive(dark: false), .primary)
        XCTAssertEqual(KairoIDBrandVariant.adaptive(dark: true), .monochromeWhite)
        var rendered: [[UInt8]] = []
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: KairoIDBrandView(width: 174, variant: .primary)
                .frame(width: 174, height: 174 * 428 / 1280)
                .environment(\.colorScheme, scheme))
            renderer.scale = 3
            renderer.isOpaque = false
            rendered.append(try rgba(XCTUnwrap(renderer.cgImage)))
        }
        XCTAssertEqual(rendered[0], rendered[1], "Fixed-light Welcome artwork retains the primary mark")
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
