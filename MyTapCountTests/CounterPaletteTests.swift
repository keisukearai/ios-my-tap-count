import Testing
@testable import MyTapCount

@Suite("色プリセット")
struct CounterColorTests {
    @Test("rawValue と往復できる")
    func roundTrip() {
        for color in CounterColor.allCases {
            #expect(CounterColor(rawValue: color.rawValue) == color)
        }
    }

    @Test("デザインの7色をそのまま持つ")
    func matchesDesign() {
        #expect(CounterColor.allCases.count == 7)
        #expect(CounterColor.blue.hex == 0x2F6FD0)
        #expect(CounterColor.green.hex == 0x2F7D4F)
        #expect(CounterColor.orange.hex == 0xC4691F)
        #expect(CounterColor.purple.hex == 0x6B4FA8)
        #expect(CounterColor.red.hex == 0xB3364A)
        #expect(CounterColor.teal.hex == 0x1F7A7A)
        #expect(CounterColor.slate.hex == 0x4B5563)
    }

    @Test("色ごとに別の値になっている")
    func allDistinct() {
        #expect(Set(CounterColor.allCases.map(\.hex)).count == CounterColor.allCases.count)
    }
}

@Suite("アイコンプリセット")
struct CounterSymbolTests {
    @Test("6列グリッドが埋まる数だけ用意する")
    func fitsSixColumnGrid() {
        #expect(CounterSymbol.presets.count >= 24)
        #expect(CounterSymbol.presets.count % 6 == 0)
    }

    @Test("重複が無い")
    func noDuplicates() {
        #expect(Set(CounterSymbol.presets).count == CounterSymbol.presets.count)
    }

    @Test("既定のアイコンが選択肢に含まれる")
    func containsFallback() {
        #expect(CounterSymbol.presets.contains(CounterSymbol.fallback))
    }
}
