#!/usr/bin/env swift
//
// Generates ScreenSense's app icon.
//
//   swift Tools/make-icon.swift
//
// Renders straight to PNG with CoreGraphics so the icon is reproducible and
// tweakable in source control rather than being an opaque binary blob.
//
// The mark: the name itself, "Screen" over "Sense", set bold and flush left in
// the bottom corner of a black field, with the streak's ember as the full stop.
// The words read at home-screen size where a thin serif would not, and the one
// spot of colour is the same one the app keeps for the streak.

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette
// Matches `Theme` in ScreenSense/Views/RootView.swift.

let field = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
let paper = CGColor(red: 0.925, green: 0.922, blue: 0.902, alpha: 1)   // Theme.foreground
let ember = CGColor(red: 0.910, green: 0.573, blue: 0.353, alpha: 1)   // Theme.streak

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

    // Everything is expressed against a 1024 design grid, then scaled. CoreText
    // draws with a bottom-left origin, so the context is left unflipped and
    // design-grid baselines (measured from the top) are converted here instead.
    let s = side / 1024.0
    func baseline(_ y: CGFloat) -> CGFloat { side - y * s }

    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldSmoothFonts(false)

    // --- Background: full-bleed black. No rounded corners; iOS applies its
    // --- own mask, and baking one in shows as a dark fringe.
    ctx.setFillColor(field)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

    // --- The words.
    //
    // SF Pro Bold, the face the phone itself uses, so the icon sits with the
    // system rather than bringing a typeface of its own. Tracked in tight, as
    // display sizes want; at the default spacing the two lines read as loose
    // words rather than as one block.
    let fontSize: CGFloat = 214
    let font = NSFont.systemFont(ofSize: fontSize * s, weight: .bold) as CTFont
    let tracking: CGFloat = -14

    func line(_ runs: [(String, CGColor)]) -> CTLine {
        let text = NSMutableAttributedString()
        for (string, colour) in runs {
            text.append(NSAttributedString(string: string, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour,
                NSAttributedString.Key(kCTKernAttributeName as String): tracking * s,
            ]))
        }
        return CTLineCreateWithAttributedString(text)
    }

    // Flush left on a shared margin, sat low so the field above them is the
    // quiet part of the icon and the words carry its weight.
    let margin: CGFloat = 120
    let lines: [(CTLine, CGFloat)] = [
        (line([("Screen", paper)]), 660),
        (line([("Sense", paper), (".", ember)]), 860),
    ]
    for (text, y) in lines {
        ctx.textPosition = CGPoint(x: margin * s, y: baseline(y))
        CTLineDraw(text, ctx)
    }

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
