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
- **アプリ本体はライト固定**（`RootView` の `.preferredColorScheme(.light)`）。`Shared/Theme.swift` は固定のライト色だけで、デザイン（dc.html）に暗色パレットが無い。固定しないとダーク時にシステム色の文字（白）が白いカードに載って読めなくなる。ウィジェットは `.containerBackground(.background)` と `.secondary` を使っておりダークに追従するので、こちらは固定しない（MyNfcTapLog と同じ方針）

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
- **`-screen` 起動引数は初回のみ発火させる。** `RootView` の `.task { openRequestedScreen() }` は
  `HomeView` に付いているため、詳細などから一覧に戻るたびに走り直す。
  `didOpenRequestedScreen` のガードが無いと「戻ると追加・編集画面が開き直す」「詳細が再 push される」
  という形で出る。デバッグ用の起動引数が原因なので、素の不具合と紛らわしい

## 実機の自動操作（Appium）

`~/workspace/ios/appium-poc/` に実機 arai13 を操作する仕組みがある（このリポジトリの外）。
手順は同ディレクトリの README.md。要点だけ：

- トンネル（`tunnel.sh` / **sudo・常駐**）と Appium サーバー（`serve.sh` / 常駐）の2プロセスが要る。
  iOS 18 以降の実機は Remote XPC トンネル必須
- `node do.mjs dump | tap "ラベル" | type "文字" | swipe up | shot` で1操作ずつ動かせる
- `node smoke.mjs` で通しテスト（起動→要素取得→タップ→入力→スワイプ→撮影）
- **端末の AssistiveTouch は OFF にする。** 浮いている丸ボタンがツールバーの ＋ に重なると
  タップを横取りされ、Appium 側は成功を返すのに画面が変わらない、という形で出る
- このアプリには accessibilityIdentifier を付けていないので、要素はラベル（`カウンターを追加`
  `設定` `キャンセル` `保存` など）で引いている

## App Store 提出（fastlane）

姉妹プロジェクト **MyNfcTapLog と同じ最小構成**。テキストのメタデータだけ fastlane で上げ、
**バイナリは Xcode の Organizer から手動でアップロードする**（`skip_binary_upload: true`）。
MyGeoWarp / task-count-down 等にある `beta` / `submit` / `release` レーンは意図的に持たない。

```bash
# Homebrew の Ruby を使う。PATH を通さないとシステム Ruby 2.6 + Bundler 1.17 が拾われ、
# /Library/Ruby へ書こうとして sudo を要求して失敗する（bundle config set --local も効かない）
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

bundle install                                       # vendor/bundle に入る（.bundle/config で設定済み）
cp fastlane/.env.local.example fastlane/.env.local   # 実値を埋める（他プロジェクトの .env.local から流用）
bundle exec fastlane ios upload_metadata             # ja / en-US のメタデータを ASC へ
```

- `.bundle/` `vendor/bundle/` `Gemfile.lock` は姉妹プロジェクトに合わせて .gitignore 済み
- `fastlane/.env.local` は **.gitignore 済み**。App Store Connect API キー等が入るのでコミットしない。
  中身は `~/workspace/ios/MyNfcTapLog/fastlane/.env.local` から流用した（同一 Apple アカウント）。
  match は使わないので `MATCH_*` は入れていない
- URL の規約：プライバシーは `https://kotoragk.com/<sku小文字>/privacy`、サポートは `https://kotoragk.com/<sku小文字>`。
  **`/privacy` の方しか実在しない**
- メタデータの実体は `fastlane/metadata/{ja,en-US}/*.txt`。**ASC の画面で直接直さず、このファイルを直して上げ直す**
- カテゴリは `fastlane/metadata/primary_category.txt` の `UTILITIES`。
  pbxproj の `INFOPLIST_KEY_LSApplicationCategoryType` は主に macOS 向けの値で、審査に効くのは前者
- 文字数上限：name 30 / subtitle 30 / keywords 100 / promotional_text 170 / description 4000
- スクリーンショットは `upload_metadata` では触らない（`skip_screenshots: true`）。
  **撮影は `./fastlane/capture_screenshots.sh`、アップロードは `bundle exec fastlane ios upload_screenshots`** と分けてある

### スクリーンショットの撮り方

```bash
./fastlane/capture_screenshots.sh                       # fastlane/screenshots/{ja,en-US}/ に 5 枚ずつ
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle exec fastlane ios upload_screenshots
```

- 機種は **iPhone 14 Plus（1284 x 2778）**。App Store の 6.5 インチ枠がそのまま受け付けるサイズ。
  1242 x 2688（iPhone 11 Pro Max）でも可
- 言語は **`-AppleLanguages` 起動引数**で切り替える。`Localizer` は保存値が無いとき
  `Locale.preferredLanguages` を見る（`AppLanguage.systemDefault`）ので、設定画面を操作せずに撮り分けられる。
  **`SampleData` の項目名も同じ判定で ja / en が切り替わる**（英語版に「水」「腕立て」が出ないようにするため）
- **DEBUG ビルドで撮る。** `SampleData` と `ScreenshotMode` が DEBUG のみのため
- 撮る画面は ホーム / 詳細 / 追加 / ウィジェット設置ガイド / 設定 の5枚。
  設定画面は情報が薄いので、ストアに載せるのは上4枚で足りる
- 時計を 9:41 に固定するため `simctl status_bar override` をかけている

### 提出まわりで入れてある設定

- `Shared/PrivacyInfo.xcprivacy` — `Localizer` / `AppGroup` が `UserDefaults` を使うため
  Required Reason API の申告が要る（理由コード `CA92.1` = 自App・同一 App Group 内からのアクセス）。
  `Shared/` に置くことで **本体と拡張の両バンドルにコピーされる**（ビルド成果物で確認済み）。
  データ収集・トラッキングはいずれも無しで申告している
- `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` — アップロードのたびに聞かれる
  輸出コンプライアンス質問をスキップする。生成 Info.plist に `<false/>` で入ることを確認済み

## リリース状況

**1.0 を 2026-09-11 に審査提出済み。ASC の状態は `WAITING_FOR_REVIEW`（審査待ち）**
（Apple ID `6809613034` / SKU `MyTapCount`）。公開中バージョンはまだ無い。

**審査待ち中にサポート URL 等のメタデータを直すには、いったん「デベロッパーにより却下」で
審査から取り下げる必要がある。** 取り下げてもビルドとメタデータは残る（状態が
`DEVELOPER_REJECTED` になるだけ）ので、直したあと「審査に提出」を押し直せばよく、
再アーカイブもアップロードも要らない。ただし審査の列には並び直しになる。

## TODO

- [ ] 実機（arai13）で small / medium ウィジェットの ＋ 動作を確認する
- [ ] App Store Connect の「App情報」でカテゴリ・年齢制限（4+）・App プライバシー（データを収集しません）を設定する
- [x] `fastlane/.env.local` を作って `bundle exec fastlane ios upload_metadata` を実行する（2026-09-11 実施・ASC 反映確認済み）
- [x] スクリーンショットを撮る（`./fastlane/capture_screenshots.sh` / 1284 x 2778 / ja・en 各5枚）
- [x] スクリーンショットを ASC に上げる（`bundle exec fastlane ios upload_screenshots`）
- [ ] App プレビュー（動画）は未作成。任意項目なので無くても公開できた
- [x] Xcode の Organizer から Archive → App Store Connect へアップロード
- [x] サポート URL を ja / en-US とも `https://kotoragk.com/mytapcount/privacy` に揃える（200 確認済み）
- [ ] サポート専用ページを用意する。今はサポート URL がプライバシーポリシーを指しているので、
      審査で指摘される可能性が残る。`https://kotoragk.com/<sku小文字>` は実在しない
      （MyGeoWarp 等の既存アプリも同じ状態）
- [x] AppIcon を用意する（`Assets.xcassets/AppIcon.appiconset` に 1024 / Dark / Tinted）
- [x] App Store Connect にアプリ登録（**SKU は `MyTapCount`** / Apple ID `6809613034`）
- [x] git リポジトリの作成と初期コミット（リモート: `git@github.com:keisukearai/ios-my-tap-count.git` / main ブランチ）
