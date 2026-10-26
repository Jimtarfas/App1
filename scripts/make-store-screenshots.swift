// Renders framed App Store screenshots (no alpha) at 6.9" (1320×2868) and 6.5" (1284×2778).
// Usage: swift scripts/make-store-screenshots.swift marketing/screenshots/captions.json marketing/screenshots/raw marketing/screenshots
import AppKit

struct Shot: Decodable {
    let raw: String
    let name: String
    let headline: String
    let subheadline: String
    var premium: Bool? = nil
}

let args = CommandLine.arguments
let shots = try! JSONDecoder().decode([Shot].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let rawDir = args[2], outDir = args[3]
let sizes = [("6.9", 1320, 2868), ("6.5", 1284, 2778)]

func fitted(_ text: String, weight: NSFont.Weight, maxSize: CGFloat, minSize: CGFloat, width: CGFloat, height: CGFloat, color: NSColor) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byWordWrapping
    var size = maxSize
    while true {
        let string = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph,
        ])
        let bounds = string.boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
        if bounds.height <= height || size <= minSize { return string }
        size -= 4
    }
}

func render(_ shot: Shot, raw: NSImage, width: Int, height: Int, to output: URL) {
    let scale = CGFloat(width) / 1320
    let w = CGFloat(width), h = CGFloat(height)
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

    NSGradient(colors: [NSColor(red: 0.05, green: 0.06, blue: 0.13, alpha: 1),
                        NSColor(red: 0.16, green: 0.12, blue: 0.40, alpha: 1),
                        NSColor(red: 0.27, green: 0.20, blue: 0.70, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 90)

    // Captions are centered in the band above the phone, which starts at the same height on every shot.
    let phoneTop = h - 740 * scale
    let textWidth = w - 140 * scale
    let headline = fitted(shot.headline, weight: .heavy, maxSize: 108 * scale, minSize: 72 * scale, width: textWidth, height: 250 * scale, color: .white)
    let subheadline = fitted(shot.subheadline, weight: .medium, maxSize: 50 * scale, minSize: 36 * scale, width: textWidth, height: 120 * scale,
                             color: NSColor(white: 1, alpha: 0.78))
    let headlineHeight = ceil(headline.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).height)
    let subheadlineHeight = ceil(subheadline.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).height)
    let badge = NSAttributedString(string: "PREMIUM", attributes: [
        .font: NSFont.systemFont(ofSize: 38 * scale, weight: .heavy), .foregroundColor: NSColor.black, .kern: 3 * scale,
    ])
    let badgeHeight = shot.premium == true ? badge.size().height + 20 * scale : 0
    let badgeGap = shot.premium == true ? 26 * scale : 0
    let blockHeight = badgeHeight + badgeGap + headlineHeight + 20 * scale + subheadlineHeight
    var top = phoneTop + 40 * scale + ((h - phoneTop - 40 * scale) - blockHeight) / 2 + blockHeight

    if shot.premium == true {
        let size = badge.size()
        let pill = NSRect(x: (w - size.width - 56 * scale) / 2, y: top - badgeHeight, width: size.width + 56 * scale, height: badgeHeight)
        NSColor(red: 1.0, green: 0.78, blue: 0.30, alpha: 1).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        badge.draw(at: NSPoint(x: pill.minX + 28 * scale, y: pill.minY + 10 * scale))
        top = pill.minY - badgeGap
    }
    headline.draw(with: NSRect(x: 70 * scale, y: top - headlineHeight, width: textWidth, height: headlineHeight), options: [.usesLineFragmentOrigin])
    top -= headlineHeight + 20 * scale
    subheadline.draw(with: NSRect(x: 70 * scale, y: top - subheadlineHeight, width: textWidth, height: subheadlineHeight), options: [.usesLineFragmentOrigin])

    // The phone screen sits below the captions and runs off the bottom edge.
    let shotWidth = 1000 * scale
    let shotHeight = shotWidth * raw.size.height / raw.size.width
    let shotTop = phoneTop
    let shotRect = NSRect(x: (w - shotWidth) / 2, y: shotTop - shotHeight, width: shotWidth, height: shotHeight)
    let clip = NSBezierPath(roundedRect: shotRect, xRadius: 96 * scale, yRadius: 96 * scale)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.5)
    shadow.shadowBlurRadius = 60 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -20 * scale)
    shadow.set()
    NSColor.black.setFill()
    clip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    raw.draw(in: shotRect)
    NSGraphicsContext.restoreGraphicsState()
    NSColor(white: 1, alpha: 0.25).setStroke()
    clip.lineWidth = 8 * scale
    clip.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

for (label, width, height) in sizes {
    let dir = URL(fileURLWithPath: outDir).appendingPathComponent(label)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for shot in shots {
        let raw = NSImage(contentsOfFile: "\(rawDir)/\(shot.raw).png")!
        render(shot, raw: raw, width: width, height: height, to: dir.appendingPathComponent(shot.name + ".png"))
    }
    print("rendered \(label)\"")
}
