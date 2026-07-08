#!/usr/bin/env swift
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outputDir = "icon-variants"

// MARK: - Colors (as RGBA components)

let bgTopR: CGFloat = 0.04,  bgTopG: CGFloat = 0.086, bgTopB: CGFloat = 0.157   // #0a1628
let bgBotR: CGFloat = 0.102, bgBotG: CGFloat = 0.29,   bgBotB: CGFloat = 0.42    // #1a4a6b
let greenR: CGFloat = 0.204, greenG: CGFloat = 0.78,   greenB: CGFloat = 0.349   // #34c759

func cgColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// MARK: - Drawing Helpers

func drawGradientBackground(in ctx: CGContext, rect: CGRect) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [cgColor(bgTopR, bgTopG, bgTopB), cgColor(bgBotR, bgBotG, bgBotB)] as CFArray
    let locations: [CGFloat] = [0, 1]
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: rect.width, y: rect.height), options: [])
}

func drawRadialGlow(in ctx: CGContext, center: CGPoint, radius: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat) {
    for i in stride(from: 1.0, through: 0.0, by: -0.05) {
        let rad = radius * CGFloat(i)
        let alpha = CGFloat(1.0 - i) * 0.15
        ctx.setFillColor(cgColor(r, g, b, alpha))
        ctx.fillEllipse(in: CGRect(x: center.x - rad, y: center.y - rad, width: rad * 2, height: rad * 2))
    }
}

func drawTerminalPrompt(in ctx: CGContext, at center: CGPoint, fontSize: CGFloat) {
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let str = NSAttributedString(string: ">_", attributes: attrs)
    let line = CTLineCreateWithAttributedString(str as CFAttributedString)
    let bounds = CTLineGetBoundsWithOptions(line, [])
    let x = center.x - bounds.width / 2
    let y = center.y - bounds.height / 2 - bounds.origin.y
    ctx.saveGState()
    ctx.translateBy(x: x, y: y)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func drawCursorDot(in ctx: CGContext, center: CGPoint, radius: CGFloat) {
    // Green glow
    for i in stride(from: 1.0, through: 0.0, by: -0.1) {
        let r = radius * CGFloat(2.5) * CGFloat(i)
        let alpha = CGFloat(1.0 - i) * 0.2
        ctx.setFillColor(cgColor(greenR, greenG, greenB, alpha))
        ctx.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }
    // Solid dot
    ctx.setFillColor(cgColor(greenR, greenG, greenB))
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func drawGitBranch(in ctx: CGContext, at center: CGPoint, scale: CGFloat) {
    let lineWidth: CGFloat = 18 * scale
    ctx.setStrokeColor(cgColor(1, 1, 1, 0.25))
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)

    let trunkTop = center.y + 120 * scale
    let trunkBottom = center.y - 120 * scale

    // Vertical trunk
    ctx.move(to: CGPoint(x: center.x, y: trunkTop))
    ctx.addLine(to: CGPoint(x: center.x, y: trunkBottom))
    ctx.strokePath()

    // Top branch (right)
    ctx.move(to: CGPoint(x: center.x, y: trunkTop))
    ctx.addLine(to: CGPoint(x: center.x + 60 * scale, y: trunkTop - 50 * scale))
    ctx.strokePath()

    // Bottom branch (left)
    ctx.move(to: CGPoint(x: center.x, y: trunkBottom))
    ctx.addLine(to: CGPoint(x: center.x - 60 * scale, y: trunkBottom + 50 * scale))
    ctx.strokePath()

    // Node dots
    ctx.setFillColor(cgColor(1, 1, 1, 0.4))
    let dotR: CGFloat = 10 * scale
    let nodes = [
        CGPoint(x: center.x, y: trunkTop),
        CGPoint(x: center.x, y: trunkBottom),
        CGPoint(x: center.x + 60 * scale, y: trunkTop - 50 * scale)
    ]
    for n in nodes {
        ctx.fillEllipse(in: CGRect(x: n.x - dotR, y: n.y - dotR, width: dotR * 2, height: dotR * 2))
    }
}

// MARK: - Variant Generators

func generateVariant1() -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }
    drawGradientBackground(in: ctx, rect: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
    drawRadialGlow(in: ctx, center: CGPoint(x: size/2, y: size/2), radius: 350, r: greenR, g: greenG, b: greenB)
    drawTerminalPrompt(in: ctx, at: CGPoint(x: size/2, y: size/2 + 30), fontSize: 280)
    drawCursorDot(in: ctx, center: CGPoint(x: size/2 + 180, y: size/2 - 40), radius: 28)
    image.unlockFocus()
    return image
}

func generateVariant2() -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }
    drawGradientBackground(in: ctx, rect: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
    drawGitBranch(in: ctx, at: CGPoint(x: size/2, y: size/2), scale: 1.5)
    drawTerminalPrompt(in: ctx, at: CGPoint(x: size/2, y: size/2), fontSize: 240)
    drawCursorDot(in: ctx, center: CGPoint(x: size * 0.72, y: size * 0.3), radius: 22)
    image.unlockFocus()
    return image
}

func generateVariant3() -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }
    drawGradientBackground(in: ctx, rect: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
    drawTerminalPrompt(in: ctx, at: CGPoint(x: size/2, y: size/2 + 40), fontSize: 320)
    // Green underline bar
    let barW: CGFloat = 280, barH: CGFloat = 12
    let barRect = CGRect(x: size/2 - barW/2, y: size/2 - 120, width: barW, height: barH)
    let barPath = CGPath(roundedRect: barRect, cornerWidth: barH/2, cornerHeight: barH/2, transform: nil)
    ctx.addPath(barPath)
    ctx.setFillColor(cgColor(greenR, greenG, greenB))
    ctx.fillPath()
    drawRadialGlow(in: ctx, center: CGPoint(x: size/2, y: size/2 - 120), radius: 100, r: greenR, g: greenG, b: greenB)
    image.unlockFocus()
    return image
}

// MARK: - Save

func saveImage(_ image: NSImage, name: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { return }
    let url = URL(fileURLWithPath: "\(outputDir)/\(name).png")
    try! png.write(to: url)
    print("Saved: \(url.path)")
}

// MARK: - Main

let v1 = generateVariant1()
let v2 = generateVariant2()
let v3 = generateVariant3()

saveImage(v1, name: "variant1")
saveImage(v2, name: "variant2")
saveImage(v3, name: "variant3")

print("Done! 3 variants saved to \(outputDir)/")
