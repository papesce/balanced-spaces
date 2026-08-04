#!/usr/bin/env swift
import AppKit

let canvasSize: CGFloat = 1024
let cornerRadius: CGFloat = 185.4

func makeIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
    image.lockingFocus {
        let rect = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        bgPath.addClip()

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.20, green: 0.47, blue: 0.98, alpha: 1.0),
            NSColor(calibratedRed: 0.31, green: 0.78, blue: 0.72, alpha: 1.0)
        ])
        gradient?.draw(in: rect, angle: -55)

        // Three overlapping "space" cards fanned out, back to front.
        let cardSize = CGSize(width: 460, height: 340)
        let cardRadius: CGFloat = 56

        func drawCard(center: CGPoint, rotation: CGFloat, fill: NSColor, strokeAlpha: CGFloat) {
            NSGraphicsContext.current?.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: center.x, yBy: center.y)
            transform.rotate(byDegrees: rotation)
            transform.concat()

            let cardRect = NSRect(x: -cardSize.width / 2, y: -cardSize.height / 2, width: cardSize.width, height: cardSize.height)
            let path = NSBezierPath(roundedRect: cardRect, xRadius: cardRadius, yRadius: cardRadius)

            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
            shadow.shadowBlurRadius = 26
            shadow.shadowOffset = NSSize(width: 0, height: -10)
            shadow.set()

            fill.setFill()
            path.fill()

            NSColor.white.withAlphaComponent(strokeAlpha).setStroke()
            path.lineWidth = 6
            path.stroke()

            NSGraphicsContext.current?.restoreGraphicsState()
        }

        let mid = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        drawCard(center: CGPoint(x: mid.x - 90, y: mid.y - 40), rotation: -14, fill: NSColor.white.withAlphaComponent(0.30), strokeAlpha: 0.0)
        drawCard(center: CGPoint(x: mid.x + 70, y: mid.y - 10), rotation: 10, fill: NSColor.white.withAlphaComponent(0.55), strokeAlpha: 0.0)

        // Front card: white with a small filled dot + two "note lines" to suggest name+notes.
        NSGraphicsContext.current?.saveGraphicsState()
        let frontRect = NSRect(
            x: mid.x - cardSize.width / 2 + 6,
            y: mid.y - cardSize.height / 2 + 60,
            width: cardSize.width,
            height: cardSize.height
        )
        let frontPath = NSBezierPath(roundedRect: frontRect, xRadius: cardRadius, yRadius: cardRadius)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = 34
        shadow.shadowOffset = NSSize(width: 0, height: -14)
        shadow.set()
        NSColor.white.setFill()
        frontPath.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        // Accent dot (top-left of front card) — like a space's icon marker.
        let dotDiameter: CGFloat = 84
        let dotRect = NSRect(
            x: frontRect.minX + 56,
            y: frontRect.maxY - 56 - dotDiameter,
            width: dotDiameter,
            height: dotDiameter
        )
        let dotGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.29, green: 0.56, blue: 1.0, alpha: 1.0),
            NSColor(calibratedRed: 0.20, green: 0.80, blue: 0.66, alpha: 1.0)
        ])
        dotGradient?.draw(in: NSBezierPath(ovalIn: dotRect), angle: -45)

        // Two note lines.
        func drawLine(y: CGFloat, width: CGFloat, alpha: CGFloat) {
            let lineRect = NSRect(x: frontRect.minX + 56, y: y, width: width, height: 26)
            let linePath = NSBezierPath(roundedRect: lineRect, xRadius: 13, yRadius: 13)
            NSColor(calibratedWhite: 0.55, alpha: alpha).setFill()
            linePath.fill()
        }
        drawLine(y: dotRect.minY - 54, width: 300, alpha: 0.9)
        drawLine(y: dotRect.minY - 96, width: 220, alpha: 0.55)
    }
    return image
}

extension NSImage {
    func lockingFocus(_ body: () -> Void) {
        lockFocus()
        body()
        unlockFocus()
    }
}

let icon = makeIcon()
guard let tiff = icon.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to render icon\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
