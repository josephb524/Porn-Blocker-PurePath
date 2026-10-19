//
//  OnboardingArt.swift
//  Porn Blocker
//
//  Onboarding's own artwork, drawn in the language of the app icon and
//  splash — the red shield with its white check, four-point sparks, soft
//  bubbles — instead of SF Symbols on grey circles (Jose, 2026-09-27:
//  "they look very basic"). Everything is shapes, no assets, so it stays
//  sharp at any size and needs no translation.
//
//  - `BrandShield`           the icon's shield, reusable at any size.
//  - `FeatureEmblem(kind:)`  a glyph on a gradient tile — the feature rows.
//  - `WelcomeArt`, `HowItWorksArt`, `ReminderArt`  the page heroes.
//

import SwiftUI

// MARK: - Palette

enum ArtColor {
    static let shieldTop    = Color(red: 1.00, green: 0.42, blue: 0.33)
    static let shieldBottom = Color(red: 0.86, green: 0.16, blue: 0.14)
    static let pink         = Color(red: 1.00, green: 0.55, blue: 0.62)
    static let lavender     = Color(red: 0.66, green: 0.66, blue: 1.00)
    static let amberTop     = Color(red: 1.00, green: 0.78, blue: 0.36)
    static let amberBottom  = Color(red: 1.00, green: 0.47, blue: 0.27)
}

// MARK: - Primitive shapes

/// The app icon's shield outline: a shallow roof, sides that curve into a point.
struct ShieldShape: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(0.5, 0))
        path.addLine(to: p(1, 0.16))
        path.addCurve(to: p(0.5, 1), control1: p(1, 0.62), control2: p(0.78, 0.86))
        path.addCurve(to: p(0, 0.16), control1: p(0.22, 0.86), control2: p(0, 0.62))
        path.closeSubpath()
        return path
    }
}

struct CheckShape: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.55))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return path
    }
}

/// A four-point spark, as scattered around the splash shield.
struct SparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let w = r * 0.26
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + w, y: c.y - w))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + w, y: c.y + w))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - w, y: c.y + w))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - w, y: c.y - w))
        return p
    }
}

struct HeartShape: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(0.5, 0.95))
        path.addCurve(to: p(0.02, 0.35), control1: p(0.2, 0.72), control2: p(0.02, 0.58))
        path.addCurve(to: p(0.5, 0.2), control1: p(0.02, 0.05), control2: p(0.38, 0.0))
        path.addCurve(to: p(0.98, 0.35), control1: p(0.62, 0.0), control2: p(0.98, 0.05))
        path.addCurve(to: p(0.5, 0.95), control1: p(0.98, 0.58), control2: p(0.8, 0.72))
        path.closeSubpath()
        return path
    }
}

struct FlameShape: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(0.52, 0))
        path.addCurve(to: p(0.9, 0.6), control1: p(0.66, 0.24), control2: p(0.92, 0.36))
        path.addCurve(to: p(0.5, 1), control1: p(0.9, 0.85), control2: p(0.72, 1))
        path.addCurve(to: p(0.1, 0.6), control1: p(0.28, 1), control2: p(0.1, 0.85))
        path.addCurve(to: p(0.34, 0.3), control1: p(0.1, 0.46), control2: p(0.24, 0.38))
        path.addCurve(to: p(0.52, 0), control1: p(0.42, 0.22), control2: p(0.54, 0.14))
        path.closeSubpath()
        return path
    }
}

struct BellShape: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(0.18, 0.74))
        path.addLine(to: p(0.18, 0.46))
        path.addCurve(to: p(0.5, 0.08), control1: p(0.18, 0.22), control2: p(0.32, 0.08))
        path.addCurve(to: p(0.82, 0.46), control1: p(0.68, 0.08), control2: p(0.82, 0.22))
        path.addLine(to: p(0.82, 0.74))
        path.addLine(to: p(0.94, 0.86))
        path.addLine(to: p(0.06, 0.86))
        path.closeSubpath()
        return path
    }
}

// MARK: - Brand shield

/// The icon's shield: red gradient, the lighter fold on its right, the
/// white inner shield and the red check.
struct BrandShield: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            ShieldShape()
                .fill(LinearGradient(colors: [ArtColor.shieldTop, ArtColor.shieldBottom],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            // The fold: a lighter band down the right side, as on the icon.
            ShieldShape()
                .fill(Color.white.opacity(0.14))
                .mask(Rectangle().frame(width: size * 0.5).offset(x: size * 0.25))
            ShieldShape()
                .fill(Color.white)
                .frame(width: size * 0.56, height: size * 0.62)
                .offset(y: -size * 0.02)
            CheckShape()
                .stroke(ArtColor.shieldBottom, style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.3, height: size * 0.2)
                .offset(y: -size * 0.03)
        }
        .frame(width: size, height: size * 1.12)
        .shadow(color: ArtColor.shieldBottom.opacity(0.45), radius: size * 0.12, y: size * 0.06)
    }
}

// MARK: - Decorations

private struct Spark: View {
    var size: CGFloat
    var color: Color
    var body: some View { SparkShape().fill(color).frame(width: size, height: size) }
}

/// A soft round bubble holding a small drawing, like the splash's side icons.
private struct Bubble<Content: View>: View {
    var size: CGFloat
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.18))
            Circle().stroke(tint.opacity(0.35), lineWidth: 1)
            content.foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

private struct LockGlyph: View {
    var size: CGFloat
    var body: some View {
        VStack(spacing: -size * 0.08) {
            Circle()
                .trim(from: 0.5, to: 1)
                .stroke(style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(y: size * 0.12)
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .frame(width: size * 0.72, height: size * 0.52)
        }
        .frame(width: size, height: size)
    }
}

/// Slow vertical drift for the decorations. Offset only, so it never moves
/// the layout (see CLAUDE.md "Pulse animations: scale, don't resize").
private struct Floating: ViewModifier {
    var amplitude: CGFloat
    var phase: Double

    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            content.offset(y: amplitude * CGFloat(sin(t * 1.1 + phase)))
        }
    }
}

private extension View {
    func floating(_ amplitude: CGFloat = 4, phase: Double = 0) -> some View {
        modifier(Floating(amplitude: amplitude, phase: phase))
    }
}

/// A soft red glow and two faint rings behind a hero.
private struct HeroBackdrop: View {
    var size: CGFloat
    var glow: Color = ArtColor.shieldBottom

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [glow.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 0.5))
            Circle().stroke(Color.white.opacity(0.07), lineWidth: 1).frame(width: size * 0.78)
            Circle().stroke(Color.white.opacity(0.05), lineWidth: 1).frame(width: size * 0.98)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Feature emblems

enum FeatureArtKind {
    case safariBlocking, safeBrowser, buddyChat, streaks, customList
    // Safe Browse locked screen
    case domainBlocking, imageBlur, contentFilter
    // Buddy locked screen
    case empathy, anytime, onDevice
}

/// The drawing for a feature, white on its tile.
struct FeatureGlyph: View {
    let kind: FeatureArtKind

    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch kind {
                case .safariBlocking: browserShield(s)
                case .safeBrowser:    compass(s)
                case .buddyChat:      chat(s)
                case .streaks:        flame(s)
                case .customList:     list(s)
                case .domainBlocking: globe(s)
                case .imageBlur:      blurredPicture(s)
                case .contentFilter:  funnel(s)
                case .empathy:        heart(s)
                case .anytime:        clock(s)
                case .onDevice:       phoneLock(s)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// A browser window with a shield guarding it.
    private func browserShield(_ s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.12, style: .continuous)
                .stroke(Color.white, lineWidth: s * 0.08)
                .frame(width: s * 0.78, height: s * 0.62)
                .offset(x: -s * 0.06, y: -s * 0.06)
            HStack(spacing: s * 0.05) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.white).frame(width: s * 0.07) }
            }
            .offset(x: -s * 0.2, y: -s * 0.24)
            ShieldShape()
                .fill(Color.white)
                .frame(width: s * 0.38, height: s * 0.44)
                .offset(x: s * 0.24, y: s * 0.2)
            CheckShape()
                .stroke(ArtColor.shieldBottom, style: StrokeStyle(lineWidth: s * 0.06, lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.16, height: s * 0.1)
                .offset(x: s * 0.24, y: s * 0.19)
        }
    }

    /// A compass: the safe way through the web.
    private func compass(_ s: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.white, lineWidth: s * 0.08).frame(width: s * 0.8)
            Path { p in
                p.move(to: CGPoint(x: s * 0.5, y: s * 0.2))
                p.addLine(to: CGPoint(x: s * 0.6, y: s * 0.5))
                p.addLine(to: CGPoint(x: s * 0.4, y: s * 0.5))
                p.closeSubpath()
            }
            .fill(Color.white)
            .rotationEffect(.degrees(40))
            Path { p in
                p.move(to: CGPoint(x: s * 0.5, y: s * 0.8))
                p.addLine(to: CGPoint(x: s * 0.6, y: s * 0.5))
                p.addLine(to: CGPoint(x: s * 0.4, y: s * 0.5))
                p.closeSubpath()
            }
            .fill(Color.white.opacity(0.5))
            .rotationEffect(.degrees(40))
            Circle().fill(Color.white).frame(width: s * 0.1)
        }
    }

    /// Two speech bubbles, a heart in the front one.
    private func chat(_ s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.16, style: .continuous)
                .fill(Color.white.opacity(0.5))
                .frame(width: s * 0.56, height: s * 0.42)
                .offset(x: -s * 0.14, y: -s * 0.16)
            RoundedRectangle(cornerRadius: s * 0.16, style: .continuous)
                .fill(Color.white)
                .frame(width: s * 0.6, height: s * 0.46)
                .offset(x: s * 0.1, y: s * 0.1)
            Path { p in
                p.move(to: CGPoint(x: s * 0.62, y: s * 0.78))
                p.addLine(to: CGPoint(x: s * 0.8, y: s * 0.92))
                p.addLine(to: CGPoint(x: s * 0.76, y: s * 0.72))
                p.closeSubpath()
            }
            .fill(Color.white)
            HeartShape()
                .fill(Color(red: 0.55, green: 0.36, blue: 0.95))
                .frame(width: s * 0.24, height: s * 0.22)
                .offset(x: s * 0.1, y: s * 0.1)
        }
    }

    /// A block list you edit: three rows, a plus on the last.
    private func list(_ s: CGFloat) -> some View {
        ZStack {
            VStack(alignment: .leading, spacing: s * 0.12) {
                ForEach(0..<3, id: \.self) { i in
                    HStack(spacing: s * 0.08) {
                        Circle().fill(Color.white).frame(width: s * 0.12)
                        Capsule().fill(Color.white.opacity(i == 2 ? 0.5 : 1))
                            .frame(width: s * (i == 2 ? 0.34 : 0.52), height: s * 0.1)
                    }
                }
            }
            .offset(x: -s * 0.06)
            ZStack {
                Circle().fill(Color.white).frame(width: s * 0.34)
                Image(systemName: "plus")
                    .font(.system(size: s * 0.22, weight: .heavy))
                    .foregroundStyle(Color(red: 0.13, green: 0.62, blue: 0.5))
            }
            .offset(x: s * 0.3, y: s * 0.26)
        }
    }

    /// A globe with a shield guarding it.
    private func globe(_ s: CGFloat) -> some View {
        ZStack {
            ZStack {
                Circle().stroke(Color.white, lineWidth: s * 0.07)
                Ellipse().stroke(Color.white, lineWidth: s * 0.06).frame(width: s * 0.34)
                Rectangle().fill(Color.white).frame(height: s * 0.06)
            }
            .frame(width: s * 0.7, height: s * 0.7)
            .offset(x: -s * 0.08, y: -s * 0.08)
            ShieldShape().fill(Color.white)
                .frame(width: s * 0.36, height: s * 0.42)
                .offset(x: s * 0.26, y: s * 0.22)
            CheckShape()
                .stroke(ArtColor.shieldBottom, style: StrokeStyle(lineWidth: s * 0.06, lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.15, height: s * 0.1)
                .offset(x: s * 0.26, y: s * 0.21)
        }
    }

    /// A picture whose middle is frosted over.
    private func blurredPicture(_ s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.12, style: .continuous)
                .stroke(Color.white, lineWidth: s * 0.08)
                .frame(width: s * 0.84, height: s * 0.68)
            Circle().fill(Color.white).frame(width: s * 0.14).offset(x: s * 0.2, y: -s * 0.14)
            Path { p in
                p.move(to: CGPoint(x: s * 0.16, y: s * 0.76))
                p.addLine(to: CGPoint(x: s * 0.4, y: s * 0.46))
                p.addLine(to: CGPoint(x: s * 0.58, y: s * 0.66))
                p.addLine(to: CGPoint(x: s * 0.68, y: s * 0.56))
                p.addLine(to: CGPoint(x: s * 0.84, y: s * 0.76))
                p.closeSubpath()
            }
            .fill(Color.white)
            RoundedRectangle(cornerRadius: s * 0.06)
                .fill(Color.white.opacity(0.55))
                .frame(width: s * 0.84, height: s * 0.2)
                .blur(radius: s * 0.02)
        }
    }

    /// A funnel letting only clean drops through.
    private func funnel(_ s: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: s * 0.12, y: s * 0.16))
                p.addLine(to: CGPoint(x: s * 0.88, y: s * 0.16))
                p.addLine(to: CGPoint(x: s * 0.58, y: s * 0.52))
                p.addLine(to: CGPoint(x: s * 0.58, y: s * 0.78))
                p.addLine(to: CGPoint(x: s * 0.42, y: s * 0.88))
                p.addLine(to: CGPoint(x: s * 0.42, y: s * 0.52))
                p.closeSubpath()
            }
            .fill(Color.white)
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(Color.white.opacity(0.6))
                    .frame(width: s * 0.09)
                    .offset(x: s * (CGFloat(i) - 1) * 0.18, y: -s * 0.42)
            }
        }
    }

    /// A heart with a small spark: care without judgment.
    private func heart(_ s: CGFloat) -> some View {
        ZStack {
            HeartShape().fill(Color.white).frame(width: s * 0.72, height: s * 0.64).offset(y: s * 0.04)
            SparkShape().fill(Color.white).frame(width: s * 0.24, height: s * 0.24).offset(x: s * 0.34, y: -s * 0.3)
        }
    }

    /// A clock face: there at any hour.
    private func clock(_ s: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.white, lineWidth: s * 0.08).frame(width: s * 0.78)
            Capsule().fill(Color.white).frame(width: s * 0.08, height: s * 0.26).offset(y: -s * 0.11)
            Capsule().fill(Color.white).frame(width: s * 0.2, height: s * 0.08).offset(x: s * 0.08)
            Circle().fill(Color.white).frame(width: s * 0.1)
        }
    }

    /// A phone with a lock on its screen: chats stay on the device.
    private func phoneLock(_ s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.12, style: .continuous)
                .stroke(Color.white, lineWidth: s * 0.08)
                .frame(width: s * 0.5, height: s * 0.84)
            Capsule().fill(Color.white).frame(width: s * 0.14, height: s * 0.05).offset(y: -s * 0.3)
            VStack(spacing: -s * 0.02) {
                Circle().trim(from: 0.5, to: 1)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: s * 0.06, lineCap: .round))
                    .frame(width: s * 0.2, height: s * 0.2)
                    .offset(y: s * 0.05)
                RoundedRectangle(cornerRadius: s * 0.04).fill(Color.white).frame(width: s * 0.28, height: s * 0.2)
            }
            .offset(y: s * 0.06)
        }
    }

    /// A flame with a brighter core.
    private func flame(_ s: CGFloat) -> some View {
        ZStack {
            FlameShape().fill(Color.white).frame(width: s * 0.62, height: s * 0.82)
            FlameShape().fill(ArtColor.amberTop).frame(width: s * 0.3, height: s * 0.4).offset(y: s * 0.17)
        }
    }
}

/// A feature glyph on its gradient tile.
struct FeatureEmblem: View {
    let kind: FeatureArtKind
    var size: CGFloat = 32

    private var colors: [Color] {
        switch kind {
        case .safariBlocking: return [ArtColor.shieldTop, ArtColor.shieldBottom]
        case .safeBrowser:    return [Color(red: 0.36, green: 0.66, blue: 1.0), Color(red: 0.18, green: 0.38, blue: 0.92)]
        case .buddyChat:      return [Color(red: 0.76, green: 0.56, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.9)]
        case .streaks:        return [ArtColor.amberTop, ArtColor.amberBottom]
        case .customList:     return [Color(red: 0.3, green: 0.85, blue: 0.68), Color(red: 0.1, green: 0.58, blue: 0.48)]
        case .domainBlocking: return [ArtColor.shieldTop, ArtColor.shieldBottom]
        case .imageBlur:      return [Color(red: 0.36, green: 0.66, blue: 1.0), Color(red: 0.18, green: 0.38, blue: 0.92)]
        case .contentFilter:  return [Color(red: 0.3, green: 0.85, blue: 0.68), Color(red: 0.1, green: 0.58, blue: 0.48)]
        case .empathy:        return [Color(red: 1.0, green: 0.55, blue: 0.66), Color(red: 0.9, green: 0.3, blue: 0.5)]
        case .anytime:        return [ArtColor.amberTop, ArtColor.amberBottom]
        case .onDevice:       return [Color(red: 0.76, green: 0.56, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.9)]
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
            FeatureGlyph(kind: kind)
                .padding(size * 0.2)
        }
        .frame(width: size, height: size)
        .shadow(color: colors[1].opacity(0.45), radius: size * 0.15, y: size * 0.08)
    }
}

// MARK: - Page heroes

/// Welcome: the brand shield among bubbles and sparks, as on the splash.
struct WelcomeArt: View {
    var body: some View {
        ZStack {
            HeroBackdrop(size: 210)
            Bubble(size: 40, tint: ArtColor.lavender) {
                ShieldShape().frame(width: 16, height: 18)
            }
            .offset(x: -88, y: -38).floating(4, phase: 0.4)
            Bubble(size: 44, tint: ArtColor.lavender) { LockGlyph(size: 20) }
                .offset(x: 88, y: 20).floating(5, phase: 2.1)
            Bubble(size: 38, tint: ArtColor.pink) {
                HeartShape().frame(width: 17, height: 15)
            }
            .offset(x: -64, y: 58).floating(4, phase: 3.3)
            Spark(size: 16, color: ArtColor.pink).offset(x: -40, y: -84).floating(3, phase: 1.0)
            Spark(size: 20, color: ArtColor.lavender).offset(x: 62, y: -74).floating(3, phase: 2.6)
            Spark(size: 12, color: ArtColor.pink).offset(x: 80, y: -36).floating(2, phase: 0.2)
            Spark(size: 13, color: ArtColor.pink).offset(x: 54, y: 78).floating(3, phase: 1.7)
            BrandShield(size: 104)
        }
        .frame(width: 220, height: 200)
        .accessibilityHidden(true)
    }
}

/// How It Works: the shield with the four feature emblems around it — the
/// same four as the rows below.
struct HowItWorksArt: View {
    var body: some View {
        ZStack {
            HeroBackdrop(size: 200)
            FeatureEmblem(kind: .safariBlocking, size: 40).offset(x: -78, y: -46).floating(4, phase: 0.3)
            FeatureEmblem(kind: .safeBrowser, size: 40).offset(x: 78, y: -46).floating(4, phase: 1.5)
            FeatureEmblem(kind: .buddyChat, size: 40).offset(x: -78, y: 46).floating(4, phase: 2.7)
            FeatureEmblem(kind: .streaks, size: 40).offset(x: 78, y: 46).floating(4, phase: 3.9)
            Spark(size: 14, color: ArtColor.pink).offset(x: 0, y: -84)
            Spark(size: 11, color: ArtColor.lavender).offset(x: 0, y: 86)
            BrandShield(size: 82)
        }
        .frame(width: 220, height: 190)
        .accessibilityHidden(true)
    }
}

/// Reminder: a warm bell ringing, with a small shield-check on it.
struct ReminderArt: View {
    var body: some View {
        ZStack {
            HeroBackdrop(size: 190, glow: ArtColor.amberBottom)
            ForEach(0..<2, id: \.self) { i in
                let r = CGFloat(62 + i * 16)
                Circle()
                    .trim(from: 0.05, to: 0.15)
                    .stroke(Color.white.opacity(0.35 - Double(i) * 0.15), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: r * 2, height: r * 2)
                Circle()
                    .trim(from: 0.85, to: 0.95)
                    .stroke(Color.white.opacity(0.35 - Double(i) * 0.15), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: r * 2, height: r * 2)
            }
            .rotationEffect(.degrees(-90))
            ZStack {
                BellShape()
                    .fill(LinearGradient(colors: [ArtColor.amberTop, ArtColor.amberBottom],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 84, height: 84)
                Circle().fill(ArtColor.amberBottom).frame(width: 16).offset(y: 42)
                Circle().fill(ArtColor.amberTop).frame(width: 10).offset(y: -38)
            }
            .shadow(color: ArtColor.amberBottom.opacity(0.45), radius: 12, y: 6)
            BrandShield(size: 34).offset(x: 34, y: -26)
            Spark(size: 15, color: ArtColor.pink).offset(x: -64, y: -52).floating(3, phase: 0.8)
            Spark(size: 12, color: ArtColor.lavender).offset(x: 70, y: 50).floating(3, phase: 2.2)
        }
        .frame(width: 200, height: 170)
        .accessibilityHidden(true)
    }
}

/// Safe Browse locked screen: a browser window the shield guards — a site
/// struck through, a picture frosted over.
struct SafeBrowseArt: View {
    var body: some View {
        ZStack {
            HeroBackdrop(size: 210, glow: Color(red: 0.2, green: 0.45, blue: 0.95))
            // The browser window.
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    ForEach([ArtColor.shieldTop, ArtColor.amberTop, Color(red: 0.3, green: 0.85, blue: 0.68)], id: \.self) { c in
                        Circle().fill(c).frame(width: 7)
                    }
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 10).padding(.leading, 6)
                }
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Color.white.opacity(0.1))
                VStack(alignment: .leading, spacing: 8) {
                    // A blocked result: struck through, in red.
                    HStack(spacing: 6) {
                        Circle().stroke(ArtColor.shieldTop, lineWidth: 2).frame(width: 12)
                            .overlay(Rectangle().fill(ArtColor.shieldTop).frame(width: 12, height: 2).rotationEffect(.degrees(-45)))
                        Capsule().fill(ArtColor.shieldTop.opacity(0.55)).frame(width: 70, height: 7)
                    }
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: 96, height: 7)
                    Capsule().fill(Color.white.opacity(0.22)).frame(width: 74, height: 7)
                    // A picture, frosted over.
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.66, blue: 1.0).opacity(0.7), ArtColor.lavender.opacity(0.5)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 40)
                        .blur(radius: 5)
                        .overlay(
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        )
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 150, height: 132)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hue: 0.62, saturation: 0.45, brightness: 0.22))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            .offset(x: -14, y: -4)
            BrandShield(size: 54).offset(x: 62, y: 44)
            Spark(size: 15, color: ArtColor.pink).offset(x: -86, y: -66).floating(3, phase: 0.6)
            Spark(size: 18, color: ArtColor.lavender).offset(x: 80, y: -70).floating(3, phase: 2.0)
            Spark(size: 11, color: ArtColor.pink).offset(x: -92, y: 58).floating(2, phase: 3.1)
        }
        .frame(width: 220, height: 190)
        .accessibilityHidden(true)
    }
}

/// Buddy locked screen: a conversation — your message, the buddy's warm
/// reply with a heart, the next reply already typing.
struct BuddyArt: View {
    private let purpleTop = Color(red: 0.76, green: 0.56, blue: 1.0)
    private let purpleBottom = Color(red: 0.5, green: 0.3, blue: 0.9)

    var body: some View {
        ZStack {
            HeroBackdrop(size: 210, glow: purpleBottom)
            // The user's message, right.
            bubble(width: 104, height: 40, fill: AnyShapeStyle(Color.white.opacity(0.16)), tailRight: true) {
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().fill(Color.white.opacity(0.7)).frame(width: 64, height: 6)
                    Capsule().fill(Color.white.opacity(0.45)).frame(width: 44, height: 6)
                }
            }
            .offset(x: 34, y: -52)
            .floating(3, phase: 0.3)
            // The buddy's reply, left, with a heart.
            bubble(width: 128, height: 50,
                   fill: AnyShapeStyle(LinearGradient(colors: [purpleTop, purpleBottom], startPoint: .topLeading, endPoint: .bottomTrailing)),
                   tailRight: false) {
                HStack(spacing: 8) {
                    HeartShape().fill(Color.white).frame(width: 18, height: 16)
                    VStack(alignment: .leading, spacing: 5) {
                        Capsule().fill(Color.white).frame(width: 66, height: 6)
                        Capsule().fill(Color.white.opacity(0.75)).frame(width: 48, height: 6)
                    }
                }
            }
            .shadow(color: purpleBottom.opacity(0.5), radius: 12, y: 6)
            .offset(x: -24, y: 6)
            .floating(3, phase: 1.6)
            // Typing.
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color.white.opacity(0.85 - Double(i) * 0.2)).frame(width: 7)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Capsule().fill(Color.white.opacity(0.14)))
            .offset(x: -52, y: 60)
            .floating(2, phase: 2.8)
            BrandShield(size: 34).offset(x: 66, y: 44)
            Spark(size: 16, color: ArtColor.pink).offset(x: -82, y: -60).floating(3, phase: 0.9)
            Spark(size: 12, color: ArtColor.lavender).offset(x: 88, y: -8).floating(2, phase: 2.4)
        }
        .frame(width: 220, height: 190)
        .accessibilityHidden(true)
    }

    private func bubble<Content: View>(width: CGFloat, height: CGFloat, fill: AnyShapeStyle, tailRight: Bool,
                                       @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: tailRight ? .bottomTrailing : .bottomLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill)
                .frame(width: width, height: height)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 12, y: 0))
                p.addLine(to: CGPoint(x: tailRight ? 14 : -2, y: 9))
                p.closeSubpath()
            }
            .fill(fill)
            .frame(width: 12, height: 9)
            .offset(x: tailRight ? -8 : 8, y: 7)
            content().frame(width: width, height: height)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 40) {
            WelcomeArt()
            HowItWorksArt()
            ReminderArt()
            SafeBrowseArt()
            BuddyArt()
            HStack {
                FeatureEmblem(kind: .safariBlocking)
                FeatureEmblem(kind: .safeBrowser)
                FeatureEmblem(kind: .buddyChat)
                FeatureEmblem(kind: .streaks)
            }
        }
        .padding()
    }
    .background(Color(hue: 0.6, saturation: 0.6, brightness: 0.1))
}
