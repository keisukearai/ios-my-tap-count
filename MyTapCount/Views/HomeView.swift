import SwiftUI
import SwiftData
import WidgetKit

/// 画面1: 今日のカウンター一覧。
struct HomeView: View {
    @Environment(Localizer.self) private var localizer
    @Environment(\.modelContext) private var context
    /// 並び順はユーザーが決めた順のまま。ウィジェットの表示順と一致させるため自動並べ替えはしない。
    @Query(sort: [SortDescriptor(\CounterItem.sortOrder), SortDescriptor(\CounterItem.createdAt)])
    private var counters: [CounterItem]
    /// 当日分の合計を出すためだけに使う。日付をまたいでも正しく 0 に戻るよう、
    /// クエリ側で日付を固定せず描画のたびに当日を判定する。
    @Query private var allEntries: [CountEntry]

    let onOpenDetail: (UUID) -> Void
    let onAdd: () -> Void
    let onEdit: (UUID) -> Void
    let onOpenGuide: () -> Void
    let onOpenSettings: () -> Void

    @State private var pendingDeletion: CounterItem?

    private var todayTotals: [UUID: Int] {
        let start = CountingService.startOfDay()
        return allEntries.reduce(into: [:]) { totals, entry in
            guard entry.timestamp >= start, let id = entry.counter?.id else { return }
            totals[id, default: 0] += entry.amount
        }
    }

    var body: some View {
        List {
            if counters.isEmpty {
                emptyState
            } else {
                Section {
                    ForEach(counters) { counter in
                        row(for: counter)
                    }
                    .onMove(perform: move)
                } header: {
                    Text(localizer.t("home.todayHeader"))
                } footer: {
                    Text(localizer.t("home.foot"))
                }
            }

            Section {
                guideCallout
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle(localizer.t("app.name"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if counters.count > 1 {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(localizer.t("settings.title"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(localizer.t("home.add"))
            }
        }
        .alert(localizer.t("form.deleteCounter"), isPresented: .init(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button(localizer.t("common.cancel"), role: .cancel) { pendingDeletion = nil }
            Button(localizer.t("common.delete"), role: .destructive) {
                if let counter = pendingDeletion { delete(counter) }
                pendingDeletion = nil
            }
        } message: {
            Text(localizer.t("form.deleteNote"))
        }
    }

    // MARK: - 行

    @ViewBuilder
    private func row(for counter: CounterItem) -> some View {
        let today = todayTotals[counter.id] ?? 0
        let ratio = progressRatio(today: today, target: counter.target)
        let done = counter.target.map { today >= $0 } ?? false

        HStack(spacing: 12) {
            Button {
                onOpenDetail(counter.id)
            } label: {
                HStack(spacing: 12) {
                    CounterBadge(symbol: counter.symbol, color: counter.color.color)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(counter.name)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        if let sub = subtitle(for: counter, today: today, done: done) {
                            Text(sub)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.subInk)
                        }
                    }
                    Spacer(minLength: 4)
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    CountLabel(today: today, target: counter.target)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.faintInk.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            PlusButton(color: counter.color.color) { increment(counter) }
        }
        .padding(.vertical, 6)
        .listRowBackground(progressBackground(ratio: ratio, target: counter.target, tint: counter.color.tint))
        .contextMenu {
            Button {
                onEdit(counter.id)
            } label: {
                Label(localizer.t("menu.editCounter"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeletion = counter
            } label: {
                Label(localizer.t("common.delete"), systemImage: "trash")
            }
        }
    }

    /// 目標がある項目は行の下端に進捗バーを敷く。目盛りは1回分の区切りで、
    /// 目標が大きいときは 24 分割で頭打ちにして線が潰れないようにする。
    private func progressBackground(ratio: Double?, target: Int?, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Theme.card
                if let ratio, let target, target > 0 {
                    let barHeight = proxy.size.height * 0.15
                    let segments = min(target, 24)
                    Rectangle()
                        .fill(Theme.progressTrack)
                        .frame(height: barHeight)
                    Rectangle()
                        .fill(tint)
                        .frame(width: proxy.size.width * ratio, height: barHeight)
                    ForEach(1..<segments, id: \.self) { index in
                        Rectangle()
                            .fill(Theme.progressTick)
                            .frame(width: 1, height: barHeight)
                            .offset(x: proxy.size.width * Double(index) / Double(segments))
                    }
                }
            }
        }
    }

    private func subtitle(for counter: CounterItem, today: Int, done: Bool) -> String? {
        if counter.step > 1 { return localizer.t("counter.perTap", counter.step) }
        guard let target = counter.target else { return nil }
        return done ? localizer.t("counter.targetReached") : localizer.t("counter.target", target)
    }

    // MARK: - 空状態・導線

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.accent)
            Text(localizer.t("home.empty.title"))
                .font(.system(size: 17, weight: .semibold))
            Text(localizer.t("home.empty.body"))
                .font(.system(size: 13))
                .foregroundStyle(Theme.subInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .listRowBackground(Color.clear)
    }

    private var guideCallout: some View {
        Button(action: onOpenGuide) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "plus.square")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(localizer.t("home.guideCta"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.accentDeep)
                    Text(localizer.t("home.guideCtaSub"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accentDeep.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentDeep.opacity(0.45))
            }
            .padding(14)
            .background(Theme.accentWash, in: RoundedRectangle(cornerRadius: Theme.blockRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 操作

    private func increment(_ counter: CounterItem) {
        context.insert(CountEntry(amount: counter.step, counter: counter))
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = counters
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, counter) in reordered.enumerated() { counter.sortOrder = index }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func delete(_ counter: CounterItem) {
        context.delete(counter)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
