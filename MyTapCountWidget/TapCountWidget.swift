import AppIntents
import SwiftUI
import WidgetKit

struct TapCountEntry: TimelineEntry {
    let date: Date
    let counters: [CounterSnapshot]
    /// small で表示する項目。未選択なら一覧の先頭を使う。
    let selectedID: UUID?
}

struct TapCountProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TapCountEntry {
        TapCountEntry(date: .now, counters: WidgetData.placeholders, selectedID: nil)
    }

    func snapshot(for configuration: SelectCounterIntent, in context: Context) async -> TapCountEntry {
        let counters = WidgetData.snapshots()
        return TapCountEntry(
            date: .now,
            counters: counters.isEmpty ? WidgetData.placeholders : counters,
            selectedID: configuration.counter?.id
        )
    }

    func timeline(for configuration: SelectCounterIntent, in context: Context) async -> Timeline<TapCountEntry> {
        let now = Date.now
        let selectedID = configuration.counter?.id
        let midnight = CountingService.nextMidnight(after: now)

        // 日付が変わるタイミングにもエントリを置く。当日カウントは記録の合計なので、
        // 0 時を跨いだ時点の表示（＝すべて 0）をあらかじめ作っておけば、
        // OS がリロードしてくれなくても数字が翌日にずれ込まない。
        let today = TapCountEntry(date: now, counters: WidgetData.snapshots(now: now), selectedID: selectedID)
        let tomorrow = TapCountEntry(
            date: midnight,
            counters: WidgetData.snapshots(now: now).map {
                CounterSnapshot(id: $0.id, name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex, today: 0, target: $0.target)
            },
            selectedID: selectedID
        )
        return Timeline(entries: [today, tomorrow], policy: .after(midnight))
    }
}

struct TapCountWidget: Widget {
    let kind = "MyTapCountWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectCounterIntent.self, provider: TapCountProvider()) { entry in
            TapCountWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("widget.displayName")
        .description("widget.description")
        // large / Lock Screen / StandBy は対象外。まず small と medium を確実に動かす。
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct TapCountWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TapCountEntry

    var body: some View {
        if entry.counters.isEmpty {
            Text("widget.empty")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(12)
        } else if family == .systemSmall {
            SmallWidgetView(counter: selected)
        } else {
            MediumWidgetView(counters: Array(entry.counters.prefix(4)))
        }
    }

    private var selected: CounterSnapshot {
        entry.counters.first { $0.id == entry.selectedID } ?? entry.counters[0]
    }
}

/// 画面6: small。1項目だけを大きく出し、下いっぱいに ＋ を取る。
private struct SmallWidgetView: View {
    let counter: CounterSnapshot

    private var color: Color { Color(hex: counter.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                CounterBadge(symbol: counter.symbol, color: color, side: 20)
                Text(counter.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(counter.today)")
                    .font(Theme.mono(40))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let target = counter.target {
                    Text("/ \(target)")
                        .font(Theme.mono(14, .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    ProgressRing(ratio: min(1, Double(counter.today) / Double(max(1, target))), color: color)
                        .frame(width: 26, height: 26)
                        .alignmentGuide(.lastTextBaseline) { $0[.bottom] - 2 }
                } else {
                    Spacer(minLength: 0)
                }
            }

            Spacer(minLength: 4)

            Button(intent: IncrementCounterIntent(counterID: counter.id)) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 8, trailing: 14))
    }
}

/// 画面7: medium。3〜4項目を縦に並べる。バーは入れない（狭いため）。
private struct MediumWidgetView: View {
    let counters: [CounterSnapshot]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(counters) { counter in
                let color = Color(hex: counter.colorHex)
                HStack(spacing: 0) {
                    CounterBadge(symbol: counter.symbol, color: color, side: 22)
                    Text(counter.name)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .padding(.leading, 10)
                    Spacer(minLength: 8)
                    Group {
                        if let target = counter.target {
                            Text("\(counter.today) / \(target)")
                        } else {
                            Text("\(counter.today)")
                        }
                    }
                    .font(Theme.mono(15))

                    Button(intent: IncrementCounterIntent(counterID: counter.id)) {
                        Circle()
                            .fill(color)
                            .frame(width: 26, height: 26)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            // 行が低いので、タップ領域は行の右端いっぱいに取る
                            .frame(width: 52, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
                .frame(minHeight: 32)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 6))
    }
}

/// 目標に対する進捗リング。
private struct ProgressRing: View {
    let ratio: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.25), lineWidth: 3.4)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(color, style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
