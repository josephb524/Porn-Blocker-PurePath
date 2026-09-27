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

#Preview {
    ScrollView {
        VStack(spacing: 40) {
            WelcomeArt()
            HowItWorksArt()
            ReminderArt()
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
