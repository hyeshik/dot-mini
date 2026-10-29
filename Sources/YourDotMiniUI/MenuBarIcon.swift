import AppKit

enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let path = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 16, height: 16))
            path.windingRule = .evenOdd

            // Equal holes form a downward-pointing equilateral triangle,
            // with its centroid at the center of the dot.
            let halfSpacing: CGFloat = 3
            let upperOffset = halfSpacing / CGFloat(3).squareRoot()
            let holeRadius: CGFloat = 1.4
            let centers = [
                NSPoint(x: 9 - halfSpacing, y: 9 + upperOffset),
                NSPoint(x: 9 + halfSpacing, y: 9 + upperOffset),
                NSPoint(x: 9, y: 9 - 2 * upperOffset),
            ]
            for center in centers {
                path.appendOval(in: NSRect(
                    x: center.x - holeRadius, y: center.y - holeRadius,
                    width: 2 * holeRadius, height: 2 * holeRadius
                ))
            }
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
