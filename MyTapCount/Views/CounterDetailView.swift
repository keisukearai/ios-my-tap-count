import SwiftUI
import SwiftData
import WidgetKit

/// 画面3: カウンター詳細（1週間の棒グラフ + その週の履歴）。
/// 週は ◀ ▶ で移動する。記録が無い週は飛ばす。
struct CounterDetailView: View {
    @Environment(Localizer.self) private var localizer

    let counterID: UUID
    let onEdit: (UUID) -> Void

    @Query private var counters: [CounterItem]
    /// 0 が「今日を含む直近7日」。1 増えるごとに7日ずつ古くなる。
    @State private var weekOffset = 0

    init(counterID: UUID, onEdit: @escaping (UUID) -> Void) {
        self.counterID = counterID
        self.onEdit = onEdit
        _counters = Query(filter: #Predicate<CounterItem> { $0.id == counterID })
    }

    private var counter: CounterItem? { counters.first }

    var body: some View {
        Group {
            if let counter {
                // 週が変わったら作り直す。@Query の範囲を引き直すため。
                WeekContent(counter: counter, weekOffset: $weekOffset)
                    .id(weekOffset)
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
}

// MARK: - 1週間分の中身

/// 表示中の週の記録だけを読む。`counter.entries` をたどると全期間が
/// 読み込まれてしまうので、期間を絞った `@Query` を持つ子ビューに分けている。
private struct WeekContent: View {
    @Environment(Localizer.self) private var localizer
    @Environment(\.modelContext) private var context

    let counter: CounterItem
    @Binding var weekOffset: Int

    private let window: (start: Date, end: Date)
    @Query private var windowEntries: [CountEntry]

    /// 記録のある隣の週。nil はその側の端。
    @State private var olderOffset: Int?
    @State private var newerOffset: Int?

    init(counter: CounterItem, weekOffset: Binding<Int>) {
        self.counter = counter
        self._weekOffset = weekOffset
        let window = CountingService.weekWindow(offset: weekOffset.wrappedValue)
        self.window = window
        let start = window.start
        let end = window.end
        _windowEntries = Query(
            filter: #Predicate<CountEntry> { $0.timestamp >= start && $0.timestamp < end },
            sort: [SortDescriptor(\CountEntry.timestamp, order: .reverse)]
        )
    }

    /// 期間で絞ったあと項目で選り分ける。7日分なので他項目を含めても小さい。
    private var entries: [CountEntry] {
        windowEntries.filter { $0.counter?.id == counter.id }
    }

    private var isCurrentWeek: Bool { weekOffset == 0 }

    var body: some View {
        let totals = CountingService.dayTotals(entries, window: window)
        let sections = groupByDay(entries)

        List {
            Section {
                headline(totals: totals)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                weekChart(totals: totals)
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
        .task { refreshNeighbors() }
    }

    // MARK: - 見出し

    private func headline(totals: [(date: Date, total: Int)]) -> some View {
        HStack(spacing: 14) {
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
                // 今週は「今日」の達成状況、過去の週はその週の合計を出す。
                Text(localizer.t(isCurrentWeek ? "home.todayHeader" : "detail.sum"))
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(Theme.subInk)
                if isCurrentWeek {
                    CountLabel(today: totals.last?.total ?? 0, target: counter.target, size: 24)
                } else {
                    Text(localizer.t("count.times", totals.reduce(0) { $0 + $1.total }))
                        .font(Theme.mono(24))
                        .foregroundStyle(Theme.ink)
                }
            }
            .fixedSize()
        }
    }

    // MARK: - 週の棒グラフ

    private func weekChart(totals: [(date: Date, total: Int)]) -> some View {
        let peak = max(1, totals.map(\.total).max() ?? 1, counter.target ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 2) {
                Text(AppFormat.weekRange(start: window.start, end: window.end, localizer))
                    .font(Theme.mono(15))
                    .foregroundStyle(Theme.ink)
                Spacer()
                weekStep(systemImage: "chevron.left", target: olderOffset)
                weekStep(systemImage: "chevron.right", target: newerOffset)
            }
            .padding(.trailing, -8)

            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(totals.enumerated()), id: \.offset) { index, item in
                        let isToday = isCurrentWeek && index == totals.count - 1
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
                    let isToday = isCurrentWeek && index == totals.count - 1
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

    /// 週送りボタン。行けない側は薄く出して押せなくする。
    private func weekStep(systemImage: String, target: Int?) -> some View {
        Button {
            if let target { weekOffset = target }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(target == nil ? Theme.faintInk.opacity(0.45) : Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .accessibilityLabel(localizer.t(systemImage == "chevron.left" ? "detail.olderWeek" : "detail.newerWeek"))
    }

    // MARK: - 集計

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

    private func refreshNeighbors() {
        olderOffset = try? CountingService.adjacentWeekOffset(
            counterID: counter.id, in: context, from: weekOffset, older: true
        )
        newerOffset = try? CountingService.adjacentWeekOffset(
            counterID: counter.id, in: context, from: weekOffset, older: false
        )
    }

    private func delete(_ entry: CountEntry) {
        context.delete(entry)
        try? context.save()
        // 週の最後の1件を消すと隣の週の当たり判定が変わる
        refreshNeighbors()
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
