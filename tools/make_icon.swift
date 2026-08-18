import AppKit

// Renders a 1024×1024 app icon: an indigo→cyan squircle with a white
// ECG/ticker waveform (matching the menu-bar glyph). Writes build/icon-1024.png.

let size: CGFloat = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("rep") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Squircle background with a little padding.
let pad = size * 0.055
let rect = CGRect(x: pad, y: pad, width: size - 2 * pad, height: size - 2 * pad)
let radius = rect.width * 0.235
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

ctx.saveGState()
ctx.addPath(path)
ctx.clip()
let colors = [
    NSColor(srgbRed: 0.38, green: 0.31, blue: 0.92, alpha: 1).cgColor,
    NSColor(srgbRed: 0.12, green: 0.71, blue: 0.82, alpha: 1).cgColor
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: pad, y: size - pad),
                       end: CGPoint(x: size - pad, y: pad), options: [])

// Soft highlight glow.
ctx.setBlendMode(.softLight)
let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [NSColor.white.withAlphaComponent(0.5).cgColor,
                               NSColor.clear.cgColor] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: size * 0.32, y: size * 0.72), startRadius: 0,
                       endCenter: CGPoint(x: size * 0.32, y: size * 0.72), endRadius: size * 0.6,
                       options: [])
ctx.setBlendMode(.normal)
ctx.restoreGState()

// Ticker waveform.
let w = size
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: w * x, y: w * y) }
let points = [
    p(0.15, 0.50), p(0.30, 0.50), p(0.37, 0.50), p(0.435, 0.35),
    p(0.50, 0.74), p(0.565, 0.24), p(0.63, 0.50), p(0.70, 0.50), p(0.85, 0.50)
]
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(size * 0.052)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)
ctx.setShadow(offset: .zero, blur: size * 0.02, color: NSColor.black.withAlphaComponent(0.18).cgColor)
ctx.addLines(between: points)
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()

let out = URL(fileURLWithPath: "build/icon-1024.png")
try? FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: out)
print("wrote \(out.path)")
