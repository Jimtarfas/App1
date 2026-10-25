// Draws the 1024×1024 app icon (no alpha): a white d-pad on a blue-violet gradient.
// Usage: swift scripts/make-icon.swift Zapply/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit

let size = 1024
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// Background gradient, top-left blue to bottom-right violet.
let background = CGGradient(colorsSpace: space,
                            colors: [color(0.22, 0.42, 1.0), color(0.50, 0.30, 0.98), color(0.36, 0.16, 0.78)] as CFArray,
                            locations: [0, 0.6, 1])!
context.drawLinearGradient(background, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])

// Soft light in the top-left corner.
let glow = CGGradient(colorsSpace: space, colors: [color(1, 1, 1, 0.28), color(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
context.drawRadialGradient(glow, startCenter: CGPoint(x: 260, y: 820), startRadius: 0,
                           endCenter: CGPoint(x: 260, y: 820), endRadius: 620, options: [])

let center = CGPoint(x: 512, y: 512)

// The pad, with a drop shadow.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: color(0.08, 0.04, 0.30, 0.45))
context.setFillColor(color(1, 1, 1))
context.fillEllipse(in: CGRect(x: center.x - 330, y: center.y - 330, width: 660, height: 660))
context.restoreGState()

// Four arrows.
let arrowColor = color(0.33, 0.36, 0.98)
context.setFillColor(arrowColor)
for angle in stride(from: 0.0, to: 360.0, by: 90.0) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: CGFloat(angle) * .pi / 180)
    let tip: CGFloat = 288, base: CGFloat = 212, half: CGFloat = 54
    context.move(to: CGPoint(x: 0, y: tip))
    context.addLine(to: CGPoint(x: half, y: base))
    context.addLine(to: CGPoint(x: -half, y: base))
    context.closePath()
    context.fillPath()
    context.restoreGState()
}

// The OK button.
let ok = CGGradient(colorsSpace: space, colors: [color(0.30, 0.48, 1.0), color(0.55, 0.32, 0.98)] as CFArray, locations: [0, 1])!
context.saveGState()
context.addEllipse(in: CGRect(x: center.x - 128, y: center.y - 128, width: 256, height: 256))
context.clip()
context.drawLinearGradient(ok, start: CGPoint(x: center.x - 128, y: center.y + 128), end: CGPoint(x: center.x + 128, y: center.y - 128), options: [])
context.restoreGState()

let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
CGImageDestinationFinalize(destination)
print("wrote \(output.path)")
