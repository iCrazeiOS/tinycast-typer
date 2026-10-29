// Renders assets/icon.png: a rounded gradient tile with a white keyboard glyph, matching the
// extension's 512×512 icon requirement.
import AppKit

let size = 512
guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
else {
    fatalError("Could not create the icon bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
let tile = NSBezierPath(roundedRect: canvas.insetBy(dx: 26, dy: 26), xRadius: 108, yRadius: 108)
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.36, green: 0.55, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 0.47, green: 0.33, blue: 0.98, alpha: 1),
])!
gradient.draw(in: tile, angle: -60)

if let symbol = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(
        NSImage.SymbolConfiguration(pointSize: 190, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    )
{
    let symbolSize = symbol.size
    let scale = min(300 / symbolSize.width, 220 / symbolSize.height)
    let drawn = NSSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
    let origin = NSPoint(
        x: (CGFloat(size) - drawn.width) / 2,
        y: (CGFloat(size) - drawn.height) / 2
    )
    symbol.draw(
        in: NSRect(origin: origin, size: drawn),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
}

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode the icon")
}

try png.write(to: URL(fileURLWithPath: "assets/icon.png"))
print("Wrote assets/icon.png")
