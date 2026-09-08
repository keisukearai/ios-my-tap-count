# MyTapCount

ホーム画面ウィジェットの ＋ を押すだけで「水を飲んだ」「薬を飲んだ」等の回数を記録する iPhone アプリ。
**主役はウィジェット、アプリ本体は脇役**（項目の登録と履歴の閲覧だけ）。

要件定義: `../MyTapCount-req1.md`
デザイン: https://claude.ai/design/p/745a781e-c48a-4511-992c-72c71556eb5c?file=MyTapCount.dc.html

## 技術構成

- SwiftUI + SwiftData / **最低 iOS 17.0** / iPhone 専用（`TARGETED_DEVICE_FAMILY = 1`）
- WidgetKit + App Intents（インタラクティブウィジェット。small / medium のみ）
- サーバー不要・課金なし
- Bundle ID: `com.keisukearai.MyTapCount` / ウィジェット拡張: `com.keisukearai.MyTapCount.widget` / Team: `HFZSU3MJLR`
- **App Group: `group.com.keisukearai.MyTapCount`**（本体・拡張の両方の entitlements に必要）
- 多言語: ja / en

## ターゲット構成とファイルの置き場所

Xcode 26 の **file system synchronized group** 構成。フォルダに置けば自動でターゲットに入る。

| フォルダ | 所属ターゲット |
|---|---|
| `MyTapCount/` | 本体のみ |
| `MyTapCountWidget/` | ウィジェット拡張のみ |
| `Shared/` | **本体・拡張の両方**（モデル・ストア・集計・配色・Localizer） |

- 本体と拡張の両方から使うコードは必ず `Shared/` に置く。片方にしか無いと `cannot find ... in scope` になる
- `MyTapCountWidget/Info.plist` は `INFOPLIST_FILE` で使うため、pbxproj の
  `PBXFileSystemSynchronizedBuildFileExceptionSet` でリソースコピーから除外している。
  **拡張フォルダに Info.plist を増やすときは同じ除外が要る**（無いと "Multiple commands produce Info.plist" で落ちる）

## 設計上の決めごと（変えるときは要件定義を読み直す）

- **ウィジェットには ＋ だけ置き、− は置かない**。誤タップの修正は履歴のスワイプ削除に一本化（MyNfcTapLog と同じ方針）
- **「今日のカウント」は保存せず、`CountEntry` を当日分で合計して求める**。日付が変わったときのリセット処理を持たないため、深夜またぎのバグが起きない
- **一覧の並び順は自動で変えない**（`sortOrder`）。ウィジェットの表示順とずれると「どれを押したか」が分からなくなる
- Timeline は現在と**翌 0 時**の2エントリ。0 時のエントリはカウント 0 で作り、OS がリロードしなくても数字が翌日にずれ込まないようにしている
- 拡張側は当日分の記録しか読まない（メモリ制限が厳しいため）

## ビルド・実行

```bash
# テスト（58件）
xcodebuild test -project MyTapCount.xcodeproj -scheme MyTapCount \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# ビルド
xcodebuild -project MyTapCount.xcodeproj -scheme MyTapCount \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

# シミュレータで起動（サンプルデータ付き）
xcrun simctl launch booted com.keisukearai.MyTapCount -seedSampleData

# 特定の画面を開く（DEBUG のみ / detail・settings・guide・add）
xcrun simctl launch booted com.keisukearai.MyTapCount -seedSampleData -screen detail
```

- `MyTapCount/Support/SampleData.swift` / `ScreenshotMode.swift` は **DEBUG のみ**
- 表示言語は設定画面から切り替える（`Shared/Localizer.swift` が lproj の Bundle を直接引く）。
  言語を増やすときは `AppLanguage` に case を足し、xcstrings に訳を足し、**pbxproj の `knownRegions` にも言語コードを足す**（無いと .lproj がビルドされない）

## テスト

`MyTapCountTests/` は Swift Testing（`import Testing` / `@Suite` / `@Test` / `#expect`）。MyNfcTapLog と同じ流儀。

- **`ModelContext` は `ModelContainer` を保持しない。** `container.mainContext` だけ受け取ってコンテナを手放すと、
  解放された時点で以降の SwiftData 操作が `EXC_BREAKPOINT` で落ちる。
  **落ちるタイミングが解放頼みなので、テストを1本だけ実行すると通ってしまい、本数が増えると落ちる**という出方をする。
  そのため `TestStore`（`MyTapCountTests/TestSupport.swift`）にコンテナを持たせ、
  スイートのプロパティ `private let store = TestStore()` として宣言する。Swift Testing はテストごとに
  スイートを作り直すので、これで各テストが独立したメモリ上ストアを持ちつつコンテナが生き続ける
- ストアは必ず `isStoredInMemoryOnly: true`。App Group の実ストアには触らない
- `Localizer` のテストは `UserDefaults(suiteName:)` を毎回作って渡す（実際の設定を汚さないため）

## 注意点

- **ウィジェットの更新は OS の裁量**。`reloadTimelines` を呼んでも即時とは限らず、シミュレータと実機で挙動が違う。
  **最終確認は実機（arai13）で行う**
- App Group の設定漏れは「ウィジェットにデータが出ない」という形でしか現れない。
  `Shared/AppGroup.swift` はコンテナが取れないとき黙ってフォールバックせず落とす（本体だけ動いて拡張が空、という状態を避けるため）
- SwiftData のストアは App Group コンテナの `MyTapCount.store`。既定の場所だと共有されない

## リリース前の TODO

- [ ] 実機（arai13）で small / medium ウィジェットの ＋ 動作を確認する
- [ ] AppIcon を用意する
- [ ] App Store Connect にアプリ登録（SKU は `mytapcount`）
- [ ] サポート URL・プライバシー URL（他プロジェクトは `https://kotoragk.com/<sku>` 形式）
- [ ] git リポジトリの作成と初期コミット（現状このディレクトリは git 管理外）
