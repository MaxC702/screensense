#!/usr/bin/env swift
//
// Generates ScreenSense's app icon.
//
//   swift Tools/make-icon.swift
//
// Renders straight to PNG with CoreGraphics so the icon is reproducible and
// tweakable in source control rather than being an opaque binary blob.
//
// The mark: a shield (the app blocks things) with three holes punched through
// it (the three daily breaks), echoing the pip row in HomeView.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette
// Matches Theme.accent in ScreenSense/Views/RootView.swift.

let gradientTop = CGColor(red: 0.42, green: 0.64, blue: 1.00, alpha: 1)
let gradientBottom = CGColor(red: 0.13, green: 0.25, blue: 0.78, alpha: 1)

// MARK: - Rendering

func renderIcon(size: Int) -> CGImage {
    let side = CGFloat(size)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // `noneSkipLast` produces a PNG with **no alpha channel**. App Store Connect
    // rejects app icons that carry transparency, and a fully-opaque alpha
    // channel is enough to trip that check — so we simply never make one.
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!

    // Flip to a top-left origin so the geometry below reads like screen coords.
    ctx.translateBy(x: 0, y: side)
    ctx.scaleBy(x: 1, y: -1)

    // Everything is expressed against a 1024 design grid, then scaled.
    let s = side / 1024.0
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)

    // --- Background: full-bleed diagonal gradient. No rounded corners; iOS
    // --- applies its own mask, and baking one in shows as a dark fringe.
    let background = CGGradient(
        colorsSpace: space,
        colors: [gradientTop, gradientBottom] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        background,
        start: p(0, 0),
        end: p(1024, 1024),
        options: []
    )

    // --- Soft highlight so the field doesn't read as flat vinyl.
    let highlight = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.20),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        highlight,
        startCenter: p(330, 250), startRadius: 0,
        endCenter: p(330, 250), endRadius: 640 * s,
        options: []
    )

    // --- Shield geometry.
    //
    // Tuning note: with softer corners and a shorter flank, this silhouette
    // reads as a speech bubble rather than a shield. Long straight flanks and a
    // tight top radius are what keep it unmistakable.
    let cx: CGFloat = 512
    let top: CGFloat = 236
    let bottom: CGFloat = 812
    let halfWidth: CGFloat = 250
    let corner: CGFloat = 38
    // Where the straight flanks stop and the taper to the point begins.
    let shoulder = top + (bottom - top) * 0.48
    let taper = bottom - shoulder

    let shield = CGMutablePath()
    shield.move(to: p(cx - halfWidth + corner, top))
    shield.addLine(to: p(cx + halfWidth - corner, top))
    shield.addQuadCurve(to: p(cx + halfWidth, top + corner), control: p(cx + halfWidth, top))
    shield.addLine(to: p(cx + halfWidth, shoulder))
    shield.addCurve(
        to: p(cx, bottom),
        control1: p(cx + halfWidth, shoulder + taper * 0.55),
        control2: p(cx + halfWidth * 0.60, bottom - taper * 0.05)
    )
    shield.addCurve(
        to: p(cx - halfWidth, shoulder),
        control1: p(cx - halfWidth * 0.60, bottom - taper * 0.05),
        control2: p(cx - halfWidth, shoulder + taper * 0.55)
    )
    shield.addLine(to: p(cx - halfWidth, top + corner))
    shield.addQuadCurve(to: p(cx - halfWidth + corner, top), control: p(cx - halfWidth, top))
    shield.closeSubpath()

    // --- A single bold bar: the universal "blocked" mark.
    //
    // Three pips (one per daily break) were tried here first and had to go —
    // an ellipsis inside a rounded silhouette reads as a chat bubble, and no
    // amount of spacing tuning fixed it.
    //
    // Sits above the geometric centre so it lands on the *optical* centre once
    // the taper below is accounted for.
    let barWidth: CGFloat = 244
    let barHeight: CGFloat = 62
    let barY: CGFloat = 504
    shield.addPath(CGPath(
        roundedRect: CGRect(
            x: (cx - barWidth / 2) * s,
            y: (barY - barHeight / 2) * s,
            width: barWidth * s,
            height: barHeight * s
        ),
        cornerWidth: barHeight / 2 * s,
        cornerHeight: barHeight / 2 * s,
        transform: nil
    ))

    ctx.setShadow(
        offset: CGSize(width: 0, height: 14 * s),
        blur: 40 * s,
        color: CGColor(red: 0.04, green: 0.09, blue: 0.30, alpha: 0.35)
    )
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(shield)
    // Even-odd turns the pips into holes, so the gradient shows through them
    // instead of them being flat coloured dots that would need their own colour.
    ctx.fillPath(using: .evenOdd)

    return ctx.makeImage()!
}

// MARK: - Output

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let destination = CGImageDestinationCreateWithURL(
        url, UTType.png.identifier as CFString, 1, nil
    ) else {
        FileHandle.standardError.write("Could not create \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        FileHandle.standardError.write("Could not write \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    print("wrote \(path)")
}

let root = URL(fileURLWithPath: CommandLine.arguments.first ?? ".")
    .deletingLastPathComponent()   // Tools/
    .deletingLastPathComponent()   // repo root
    .path

let iconSet = "\(root)/ScreenSense/Assets.xcassets/AppIcon.appiconset"
write(renderIcon(size: 1024), to: "\(iconSet)/AppIcon.png")

// Small proof that the mark still reads at home-screen size.
write(renderIcon(size: 120), to: "\(root)/Tools/preview-120.png")
