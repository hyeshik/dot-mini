import Foundation
import CoreGraphics

public enum DotIdentity {
    public static let bundleIdentifier = "local.YourDotMini"
    public static let entryURL = URL(string: "https://chatgpt.com/dots")!
}

public enum DotGeometry {
    // Match the pilot's Command-1 and Command-2 web viewports. Native chrome is extra.
    public static let defaultViewport = CGSize(width: 480, height: 720)
    public static let minimumViewport = CGSize(width: 420, height: 520)

    public static func clamped(_ proposed: CGRect, to screen: CGRect) -> CGRect {
        let width = min(max(1, proposed.width.isFinite ? proposed.width : defaultViewport.width), screen.width)
        let height = min(max(1, proposed.height.isFinite ? proposed.height : defaultViewport.height), screen.height)
        let x = proposed.minX.isFinite ? proposed.minX : screen.minX
        let y = proposed.minY.isFinite ? proposed.minY : screen.minY
        return CGRect(x: min(max(x, screen.minX), screen.maxX - width),
                      y: min(max(y, screen.minY), screen.maxY - height), width: width, height: height)
    }

    public static func anchored(size: CGSize, below anchor: CGRect?, in screen: CGRect) -> CGRect {
        let origin: CGPoint
        if let anchor {
            origin = CGPoint(x: anchor.maxX - size.width, y: anchor.minY - size.height - 8)
        } else {
            origin = CGPoint(x: screen.midX - size.width / 2, y: screen.maxY - size.height - 12)
        }
        return clamped(CGRect(origin: origin, size: size), to: screen)
    }
}

public enum WindowVisibility: Equatable {
    case hidden, visible

    public var toggled: Self { self == .hidden ? .visible : .hidden }
}
