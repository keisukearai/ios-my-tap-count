import SwiftUI
import SwiftData
import WidgetKit

/// 画面3: カウンター詳細（直近7日のグラフ + 履歴）。
struct CounterDetailView: View {
    @Environment(Localizer.self) private var localizer
    @Environment(\.modelContext) private var context

    let counterID: UUID
    let onEdit: (UUID) -> Void

    @Query private var counters: [CounterItem]

    init(counterID: UUID, onEdit: @escaping (UUID) -> Void) {
        self.counterID = counterID
        self.onEdit = onEdit
        _counters = Query(filter: #Predicate<CounterItem> { $0.id == counterID })
    }

    private var counter: CounterItem? { counters.first }

    var body: some View {
        Group {
            if let counter {
                content(for: counter)
            } else {
                // 編集画面から削除された直後に一瞬ここに来る
                Color.clear
            }
        }
        .navigationTitle(counter?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if counter != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizer.t("common.edit")) { onEdit(counterID) }
                }
            }
        }
    }

    private func content(for counter: CounterItem) -> some View {
        let entries = (counter.entries ?? []).sorted { $0.timestamp > $1.timestamp }
        let sections = groupByDay(entries)

        return List {
            Section {
                headline(for: counter)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                weekChart(for: counter)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(sections, id: \.day) { section in
                Section {
                    ForEach(section.entries) { entry in
                        HStack {
                            Text(AppFormat.time(entry.timestamp, localizer))
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("+\(entry.amount)")
                                .font(Theme.mono(14, .medium))
                                .foregroundStyle(Theme.subInk)
                        }
                        .swipeActions(edge: .trailing) {
                            // ウィジェットの誤タップを直す唯一の手段なので必須
                            Button(role: .destructive) {
                                delete(entry)
                            } label: {
                                Label(localizer.t("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(AppFormat.daySection(section.day, localizer))
                        Spacer()
                        Text(localizer.t("count.times", section.total))
                            .font(Theme.mono(12, .medium))
                    }
                } footer: {
                    if section.day == sections.first?.day {
                        Text(localizer.t("detail.swipeHint"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
    }

    // MARK: - 見出し

    private func headline(for counter: CounterItem) -> some View {
        let today = todayTotal(for: counter)
        return HStack(spacing: 14) {
            CounterBadge(symbol: counter.symbol, color: counter.color.color, side: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(counter.name)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let target = counter.target {
                    Text(localizer.t("counter.target", target))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.subInk)
                } else if counter.step > 1 {
                    Text(localizer.t("counter.perTap", counter.step))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.subInk)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(localizer.t("home.todayHeader"))
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(Theme.subInk)
                CountLabel(today: today, target: counter.target, size: 24)
            }
            .fixedSize()
        }
    }

    // MARK: - 直近7日の棒グラフ

    private func weekChart(for counter: CounterItem) -> some View {
        let totals = CountingService.lastWeekTotals(for: counter)
        let peak = max(1, totals.map(\.total).max() ?? 1, counter.target ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(localizer.t("detail.last7"))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.subInk)
                Spacer()
                Text(localizer.t("count.times", totals.reduce(0) { $0 + $1.total }))
                    .font(Theme.mono(15))
                    .foregroundStyle(Theme.ink)
            }

            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(totals.enumerated()), id: \.offset) { index, item in
                        let isToday = index == totals.count - 1
                        VStack(spacing: 6) {
                            Text(item.total > 0 ? "\(item.total)" : " ")
                                .font(Theme.mono(10, .medium))
                                .foregroundStyle(Theme.faintInk)
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isToday ? counter.color.color : counter.color.muted)
                                .frame(height: max(2, 88 * CGFloat(item.total) / CGFloat(peak)))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)

                if let target = counter.target {
                    // 目標線。棒の最大高さ 88pt に合わせて位置を出す。
                    ZStack(alignment: .topTrailing) {
                        Line()
                            .stroke(Theme.accent.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .frame(height: 1)
                        Text(localizer.t("counter.target", target))
                            .font(Theme.mono(10, .medium))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 3)
                            .background(Theme.card)
                            .offset(y: -6)
                    }
                    .offset(y: -88 * CGFloat(target) / CGFloat(peak))
                }
            }

            HStack(spacing: 10) {
                ForEach(Array(totals.enumerated()), id: \.offset) { index, item in
                    let isToday = index == totals.count - 1
                    Text(AppFormat.weekdayInitial(item.date, localizer))
                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Theme.ink : Theme.faintInk)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(EdgeInsets(top: 18, leading: 16, bottom: 12, trailing: 16))
        .cardSurface(radius: Theme.cardRadius)
    }

    // MARK: - 集計

    private func todayTotal(for counter: CounterItem) -> Int {
        let start = CountingService.startOfDay()
        return (counter.entries ?? []).filter { $0.timestamp >= start }.reduce(0) { $0 + $1.amount }
    }

    private struct DaySection {
        let day: Date
        let entries: [CountEntry]
        var total: Int { entries.reduce(0) { $0 + $1.amount } }
    }

    /// 「今日の記録」が常に最上部に来るよう、新しい日付から順に並べる。
    private func groupByDay(_ entries: [CountEntry]) -> [DaySection] {
        let grouped = Dictionary(grouping: entries) { CountingService.startOfDay($0.timestamp) }
        return grouped.keys.sorted(by: >).map { DaySection(day: $0, entries: grouped[$0] ?? []) }
    }

    private func delete(_ entry: CountEntry) {
        context.delete(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
