import Foundation
import CoreGraphics
import Testing
@testable import YourDotMiniCore

struct DotGeometryTests {
    @Test(arguments: [
        CGRect(x: 0, y: 0, width: 1440, height: 875),
        CGRect(x: -1920, y: 0, width: 1920, height: 1055),
        CGRect(x: 0, y: 900, width: 1440, height: 875),
        CGRect(x: 1440, y: -500, width: 800, height: 575),
        CGRect(x: 0, y: 0, width: 300, height: 300),
    ])
    func placementStaysOnScreen(_ screen: CGRect) {
        for size in [CGSize(width: 480, height: 800), CGSize(width: 3000, height: 2000)] {
            for anchor in [CGRect(x: screen.minX, y: screen.maxY, width: 24, height: 24),
                           CGRect(x: screen.maxX - 24, y: screen.maxY, width: 24, height: 24)] {
                let result = DotGeometry.anchored(size: size, below: anchor, in: screen)
                #expect(screen.contains(result))
                #expect(result.width > 0 && result.height > 0)
            }
        }
    }

    @Test func unpluggedDisplayOriginIsClamped() {
        let screen = CGRect(x: 0, y: 0, width: 1280, height: 775)
        let previous = CGRect(x: -1900, y: 1500, width: 480, height: 750)
        #expect(DotGeometry.clamped(previous, to: screen) == CGRect(x: 0, y: 25, width: 480, height: 750))
    }

    @Test func anchorAlignsRightAndBelowStatusItem() {
        let frame = DotGeometry.anchored(size: CGSize(width: 480, height: 720),
                                        below: CGRect(x: 1000, y: 875, width: 24, height: 24),
                                        in: CGRect(x: 0, y: 0, width: 1440, height: 875))
        #expect(frame == CGRect(x: 544, y: 147, width: 480, height: 720))
    }

    @Test func invalidPersistedGeometryCannotEscapeScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1280, height: 775)
        let result = DotGeometry.clamped(CGRect(x: CGFloat.nan, y: CGFloat.infinity,
                                               width: CGFloat.infinity, height: CGFloat.nan), to: screen)
        #expect(screen.contains(result))
        #expect(result.width == 480)
        #expect(result.height == 720)
    }
}
