import SwiftUI
import SwiftData
import WidgetKit

/// 画面2: カウンターの追加・編集。
struct CounterFormView: View {
    enum Subject: Identifiable {
        case new
        case existing(UUID)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let id): id.uuidString
            }
        }
    }

    @Environment(Localizer.self) private var localizer
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let subject: Subject

    @State private var name = ""
    @State private var symbol = CounterSymbol.fallback
    @State private var colorKey = CounterColor.teal
    @State private var step = 1
    @State private var usesTarget = false
    @State private var target = 8
    @State private var showDeleteConfirmation = false
    @State private var loaded = false

    private var isEditing: Bool {
        if case .existing = subject { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CounterBadge(symbol: symbol, color: colorKey.color)
                        TextField(localizer.t("form.namePlaceholder"), text: $name)
                            .font(.system(size: 17))
                    }
                    .padding(.vertical, 4)
                }

                Section(localizer.t("form.icon")) {
                    iconGrid
                }

                Section(localizer.t("form.color")) {
                    colorRow
                }

                Section(localizer.t("form.rules")) {
                    Stepper(value: $step, in: 1...100) {
                        HStack {
                            Text(localizer.t("form.step"))
                            Spacer()
                            Text("\(step)").font(Theme.mono(15))
                        }
                    }
                    Toggle(localizer.t("form.targetOn"), isOn: $usesTarget.animation())
                    if usesTarget {
                        Stepper(value: $target, in: 1...100) {
                            HStack {
                                Text(localizer.t("form.targetCount"))
                                Spacer()
                                Text("\(target)").font(Theme.mono(15))
                            }
                        }
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text(localizer.t("form.deleteCounter"))
                                .frame(maxWidth: .infinity)
                        }
                    } footer: {
                        Text(localizer.t("form.deleteNote"))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle(localizer.t(isEditing ? "form.titleEdit" : "form.titleAdd"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizer.t("common.save")) { save() }
                        .fontWeight(.bold)
                }
            }
            .confirmationDialog(
                localizer.t("form.deleteNote"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(localizer.t("common.delete"), role: .destructive) { deleteCounter() }
            }
        }
        .tint(Theme.accent)
        .task { load() }
    }

    // MARK: - 部品

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
            ForEach(CounterSymbol.presets, id: \.self) { preset in
                let selected = preset == symbol
                Button {
                    symbol = preset
                } label: {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(selected ? colorKey.color : Theme.canvas)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: preset)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(selected ? .white : Theme.ink)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var colorRow: some View {
        HStack(spacing: 12) {
            ForEach(CounterColor.allCases) { preset in
                Button {
                    colorKey = preset
                } label: {
                    Circle()
                        .fill(preset.color)
                        .frame(width: 34, height: 34)
                        .overlay {
                            Circle()
                                .stroke(Theme.ink, lineWidth: colorKey == preset ? 2 : 0)
                                .padding(-3)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 読み書き

    private func existingCounter() -> CounterItem? {
        guard case .existing(let id) = subject else { return nil }
        return try? context.fetch(FetchDescriptor<CounterItem>(predicate: #Predicate { $0.id == id })).first
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let counter = existingCounter() else { return }
        name = counter.name
        symbol = counter.symbol
        colorKey = counter.color
        step = counter.step
        usesTarget = counter.target != nil
        target = counter.target ?? 8
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? localizer.t("form.defaultName") : trimmed
        let finalTarget = usesTarget ? target : nil

        if let counter = existingCounter() {
            counter.name = finalName
            counter.symbol = symbol
            counter.colorKey = colorKey.rawValue
            counter.step = step
            counter.target = finalTarget
        } else {
            let nextOrder = (try? context.fetch(FetchDescriptor<CounterItem>()).map(\.sortOrder).max()) ?? nil
            context.insert(CounterItem(
                name: finalName,
                symbol: symbol,
                colorKey: colorKey.rawValue,
                step: step,
                target: finalTarget,
                sortOrder: (nextOrder ?? -1) + 1
            ))
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }

    private func deleteCounter() {
        if let counter = existingCounter() {
            context.delete(counter)
            try? context.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        dismiss()
    }
}
