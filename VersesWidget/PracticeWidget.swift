import SwiftUI
import WidgetKit

struct PracticeEntry: TimelineEntry {
    let date: Date
    let snapshot: PracticeSnapshot
}

struct PracticeProvider: TimelineProvider {
    func placeholder(in context: Context) -> PracticeEntry {
        PracticeEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PracticeEntry) -> Void) {
        completion(PracticeEntry(date: .now, snapshot: context.isPreview ? .sample : PracticeSnapshot.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PracticeEntry>) -> Void) {
        let now = Date.now
        let entry = PracticeEntry(date: now, snapshot: PracticeSnapshot.load() ?? PracticeSnapshot())
        let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

struct PracticeWidgetView: View {
    let entry: PracticeEntry

    var body: some View {
        Group {
            if let prayer = entry.snapshot.prayer {
                card(for: prayer)
                    .widgetURL(PracticeSnapshot.url(forPassage: prayer.id))
            } else {
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Theme.raised, for: .widget)
    }

    private func card(for prayer: PracticeSnapshot.Prayer) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(PracticeAge.label(since: prayer.lastPracticed, now: entry.date))
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)

            Text(prayer.title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .layoutPriority(1)

            Text(prayer.opening)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Theme.muted)

            Spacer(minLength: 0)

            Text("\(Percent.label(prayer.hiddenFraction)) memorized")
                .font(.caption2)
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
                .layoutPriority(1)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Verses")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.faint)

            Spacer(minLength: 0)

            Text("Add a prayer to your library")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Theme.ink)
        }
    }
}

private extension PracticeSnapshot {
    static let sample = PracticeSnapshot(
        prayer: Prayer(
            id: UUID(),
            title: "O God, Guide Me",
            opening: "O God, guide me, protect me, make of me a shining lamp and a brilliant star.",
            hiddenFraction: 0.4,
            lastPracticed: Calendar.current.date(byAdding: .day, value: -3, to: .now)
        )
    )
}

@main
struct PracticeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: PracticeSnapshot.widgetKind, provider: PracticeProvider()) { entry in
            PracticeWidgetView(entry: entry)
        }
        .configurationDisplayName("Practice")
        .description("The prayer you have gone longest without practicing.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
