import AppKit
import CoreGraphics
import Foundation

struct Bar {
    var x, y, w, h: CGFloat
}

// Original waveform geometry created for this project using Paper MCP, viewBox 0 0 40 40.
let bars: [Bar] = [
    Bar(x: 2.314, y: 17.82, w: 2.155, h: 4.441),
    Bar(x: 5.733, y: 16.09, w: 2.522, h: 7.776),
    Bar(x: 9.684, y: 13.70, w: 2.878, h: 12.58),
    Bar(x: 14.11, y: 11.22, w: 2.895, h: 17.54),
    Bar(x: 18.52, y: 8.324, w: 2.922, h: 23.35),
    Bar(x: 22.98, y: 11.22, w: 2.881, h: 17.54),
    Bar(x: 27.39, y: 13.70, w: 2.890, h: 12.58),
    Bar(x: 31.72, y: 16.09, w: 2.524, h: 7.776),
    Bar(x: 35.52, y: 17.82, w: 2.149, h: 4.441),
]

let navy = CGColor(srgbRed: 0x23 / 255, green: 0x2A / 255, blue: 0x42 / 255, alpha: 1)
let paper = CGColor(srgbRed: 0xF7 / 255, green: 0xF8 / 255, blue: 0xFA / 255, alpha: 1)

func render(size: Int, rounded: Bool) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    if rounded {
        context.clear(canvas)
        let radius = CGFloat(size) * 0.223
        let tile = CGPath(roundedRect: canvas, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.addPath(tile)
        context.setFillColor(navy)
        context.fillPath()
        context.addPath(tile)
        context.clip()
    } else {
        context.setFillColor(navy)
        context.fill(canvas)
    }

    let fraction: CGFloat = size <= 32 ? 0.84 : (size <= 64 ? 0.74 : 0.62)
    let art = CGFloat(size) * fraction
    let scale = art / 40
    let origin = (CGFloat(size) - art) / 2
    context.setFillColor(paper)
    for bar in bars {
        let rect = CGRect(
            x: origin + bar.x * scale,
            y: origin + bar.y * scale,
            width: bar.w * scale,
            height: bar.h * scale
        )
        let radius = min(rect.width, rect.height) / 2
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    }
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render-icon", code: 1)
    }
    try data.write(to: url)
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let mac = root.appendingPathComponent("CohereVoice/Resources/Assets.xcassets/AppIcon.appiconset")
let ios = root.appendingPathComponent("CohereVoiceiOS/Assets.xcassets")

let macFiles: [Int: [String]] = [
    16: ["icon_16x16.png"],
    32: ["icon_16x16@2x.png", "icon_32x32.png"],
    64: ["icon_32x32@2x.png"],
    128: ["icon_128x128.png"],
    256: ["icon_128x128@2x.png", "icon_256x256.png"],
    512: ["icon_256x256@2x.png", "icon_512x512.png"],
    1024: ["icon_512x512@2x.png"],
]

for (size, names) in macFiles {
    let image = render(size: size, rounded: false)
    for name in names {
        try writePNG(image, to: mac.appendingPathComponent(name))
    }
}

try writePNG(render(size: 1024, rounded: false), to: root.appendingPathComponent("Design/icon-1024.png"))

let iosIcon = ios.appendingPathComponent("AppIcon.appiconset")
try writePNG(render(size: 1024, rounded: false), to: iosIcon.appendingPathComponent("AppIcon-1024.png"))

let launch = ios.appendingPathComponent("LaunchMark.imageset")
let launchSizes = [(1, "LaunchMark.png"), (2, "LaunchMark@2x.png"), (3, "LaunchMark@3x.png")]
for (scale, name) in launchSizes {
    try writePNG(render(size: 96 * scale, rounded: true), to: launch.appendingPathComponent(name))
}

print("wrote icons")
