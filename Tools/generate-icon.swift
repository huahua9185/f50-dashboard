import AppKit

/// 生成 app 图标：深蓝渐变底 + 白色信号弧 + 上下行箭头。
/// 用法：swift generate-icon.swift <输出目录>，产出 AppIcon.icns。
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    let scale = size / 1024

    // macOS 图标留出四周边距，圆角用接近系统 squircle 的比例
    let inset = 60 * scale
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = 200 * scale

    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.saveGState()
    context.addPath(path)
    context.clip()

    let colors = [
        NSColor(srgbRed: 0.16, green: 0.45, blue: 0.95, alpha: 1).cgColor,
        NSColor(srgbRed: 0.05, green: 0.20, blue: 0.62, alpha: 1).cgColor,
    ]
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )
    context.restoreGState()

    // 信号柱：和菜单栏图标用同一套视觉语言，5 根递增的圆角柱
    let barCount = 5
    let barWidth = 96.0 * Double(scale)
    let gap = 38.0 * Double(scale)
    let totalWidth = Double(barCount) * barWidth + Double(barCount - 1) * gap
    let baseY = 330.0 * Double(scale)
    let maxHeight = 400.0 * Double(scale)
    var x = (Double(size) - totalWidth) / 2

    for index in 0..<barCount {
        // 最矮的一根也占 32% 高度，保证小尺寸下轮廓仍然清楚
        let ratio = 0.32 + 0.68 * Double(index) / Double(barCount - 1)
        let height = maxHeight * ratio
        let bar = CGRect(x: x, y: baseY, width: barWidth, height: height)
        // 后两根用满不透明度，前几根稍淡，做出递进感
        context.setFillColor(NSColor.white.withAlphaComponent(0.55 + 0.45 * ratio).cgColor)
        context.addPath(
            CGPath(
                roundedRect: bar,
                cornerWidth: barWidth / 2.4,
                cornerHeight: barWidth / 2.4,
                transform: nil
            )
        )
        context.fillPath()
        x += barWidth + gap
    }

    return image
}

func png(from image: NSImage, pixels: Int) -> Data? {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(size: CGFloat(pixels)).draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconset = URL(fileURLWithPath: outputDir).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// iconutil 要求的标准命名与尺寸组合
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    guard let data = png(from: NSImage(), pixels: variant.pixels) else { continue }
    try data.write(to: iconset.appendingPathComponent("\(variant.name).png"))
}
print("iconset 已生成: \(iconset.path)")
