import SwiftUI

struct WordView: View {
    let token: String
    let concealed: Bool
    var difficulty: Difficulty = .lines
    var dimmed: Bool = false
    var recited: Bool = false
    var sweeping: Bool = false
    var sweepDelay: Double = 0
    var missFlashing: Bool = false
    var staggerDelay: Double = 0

    static func parts(of token: String) -> (lead: String, core: String, trail: String) {
        let chars = Array(token)
        func isCore(_ c: Character) -> Bool { c.isLetter || c == "'" || c == "\u{2019}" }
        var i = 0
        while i < chars.count && !isCore(chars[i]) { i += 1 }
        var j = chars.count
        while j > i && !isCore(chars[j - 1]) { j -= 1 }
        return (
            String(chars[0..<i]),
            String(chars[i..<j]),
            String(chars[j..<chars.count])
        )
    }

    var body: some View {
        let p = Self.parts(of: token)
        HStack(spacing: 0) {
            if !p.lead.isEmpty { Text(p.lead).foregroundStyle(Theme.ink).opacity(p.lead == "-" ? 1 : punctuationOpacity) }
            if !p.core.isEmpty {
                Text(p.core)
                    .foregroundStyle(dimmed ? Theme.hiddenInk : Theme.ink)
                    .opacity(concealed ? 0 : 1)
                    .overlay(alignment: .bottom) {
                        concealment
                            .opacity(concealed ? 1 : 0)
                            .animation(concealed ? Motion.lineFadeIn.delay(staggerDelay) : (recited ? Motion.reveal : .easeInOut(duration: 0.18)), value: concealed)
                    }
            }
            if !p.trail.isEmpty { Text(p.trail).foregroundStyle(Theme.ink).opacity(punctuationOpacity) }
        }
        .modifier(SweepReveal(progress: sweeping ? 1 : 0, active: sweeping))
        .animation(sweeping ? Motion.sweep.delay(sweepDelay) : nil, value: sweeping)
        .background {
            if let highlight {
                RoundedRectangle(cornerRadius: Radius.word, style: .continuous)
                    .fill(highlight)
                    .padding(.horizontal, -5)
                    .padding(.vertical, -3)
            }
        }
        .animation(recited && !concealed ? Motion.reveal : Motion.fade.delay(staggerDelay), value: concealed)
        .animation(Motion.fade.delay(staggerDelay), value: dimmed)
    }

    private var punctuationOpacity: Double {
        concealed && difficulty == .blank ? 0 : 1
    }

    @ViewBuilder
    private var concealment: some View {
        switch difficulty {
        case .lines: reciteLine
        case .blank: EmptyView()
        }
    }

    private var reciteLine: some View {
        Rectangle().fill(lineColor).frame(height: 1)
    }

    private var lineColor: Color {
        if missFlashing { return Theme.warn }
        if recited { return Theme.accent }
        return Theme.faint
    }

    private var highlight: Color? {
        if missFlashing { return Theme.warn.opacity(0.2) }
        return nil
    }
}

private struct SweepReveal: ViewModifier, Animatable {
    var progress: Double
    let active: Bool

    private static let softness = 0.6

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        if active {
            let edge = progress * (1 + Self.softness) - Self.softness
            content.mask {
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: UnitPoint(x: edge, y: 0.5),
                    endPoint: UnitPoint(x: edge + Self.softness, y: 0.5)
                )
            }
        } else {
            content
        }
    }
}
