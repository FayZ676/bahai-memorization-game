import SwiftUI

struct WordView: View {
    let token: String
    let hidden: Bool
    var expected: Bool = false
    var recited: Bool = false
    var missed: Bool = false
    var missFlashing: Bool = false
    var staggerDelay: Double = 0
    @State private var pulsing = false

    private var parts: (lead: String, core: String, trail: String) {
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
        let p = parts
        HStack(spacing: 0) {
            if !p.lead.isEmpty { Text(p.lead).foregroundStyle(Theme.ink) }
            if !p.core.isEmpty {
                Text(p.core)
                    .foregroundStyle(Theme.ink)
                    .opacity(hidden ? 0 : 1)
                    .blur(radius: hidden ? 2 : 0)
                    .overlay(alignment: .bottom) {
                        reciteLine
                            .opacity(showLine ? 1 : 0)
                            .animation(hidden ? Motion.lineFadeIn.delay(staggerDelay) : .easeInOut(duration: 0.18), value: showLine)
                    }
            }
            if !p.trail.isEmpty { Text(p.trail).foregroundStyle(Theme.ink) }
        }
        .background {
            if let highlight {
                RoundedRectangle(cornerRadius: Radius.word, style: .continuous)
                    .fill(highlight)
                    .padding(.horizontal, -5)
                    .padding(.vertical, -3)
            }
        }
        .scaleEffect(pulsing ? 1.15 : 1)
        .animation(Motion.fade.delay(staggerDelay), value: hidden)
        .animation(.easeInOut(duration: 0.18), value: expected)
        .onChange(of: recited) { wasRecited, isRecited in
            guard isRecited, !wasRecited else { return }
            withAnimation(.easeOut(duration: 0.1)) { pulsing = true }
            Task {
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { pulsing = false }
            }
        }
    }

    private var showLine: Bool { hidden || expected }

    private var reciteLine: some View {
        RoundedRectangle(cornerRadius: Radius.line, style: .continuous)
            .fill(lineColor)
            .frame(height: 2)
            .offset(y: 3)
    }

    private var lineColor: Color {
        if missFlashing || missed { return Theme.warn }
        if recited || expected { return Theme.accent }
        return Theme.muted
    }

    private var highlight: Color? {
        if pulsing { return Theme.accent.opacity(0.16) }
        if missFlashing { return Theme.warn.opacity(0.2) }
        if expected { return Theme.accent.opacity(0.12) }
        return nil
    }
}

