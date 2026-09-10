#!/bin/bash
# App Store 用スクリーンショットを撮る。
#
#   ./fastlane/capture_screenshots.sh
#
# iPhone 14 Plus のシミュレータを使うのは、撮れる 1284x2778 が App Store の
# 6.5 インチ枠がそのまま受け付けるサイズだから（1242x2688 でも可）。
# 撮影後は fastlane/screenshots/{ja,en-US}/ に入る。
#
# 言語は -AppleLanguages 起動引数で切り替える。Localizer は保存値が無いとき
# Locale.preferredLanguages を見る（AppLanguage.systemDefault）ので、これで
# 設定画面を触らずに ja / en を撮り分けられる。
# SampleData の項目名も同じ判定で ja / en が切り替わる。
set -euo pipefail

BID="com.keisukearai.MyTapCount"
DEVICE_NAME="ShotDevice-14Plus"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/fastlane/screenshots"
DD="$(mktemp -d)/dd"

RUNTIME=$(xcrun simctl list runtimes --json | python3 -c \
  "import json,sys;print([r['identifier'] for r in json.load(sys.stdin)['runtimes'] if r['isAvailable'] and 'iOS' in r['name']][-1])")

UDID=$(xcrun simctl list devices --json | python3 -c "
import json,sys
for devs in json.load(sys.stdin)['devices'].values():
    for d in devs:
        if d['name'] == '$DEVICE_NAME':
            print(d['udid']); raise SystemExit
")
if [ -z "${UDID:-}" ]; then
  UDID=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

# DEBUG ビルドでないと SampleData / ScreenshotMode が入らない
xcodebuild -project "$ROOT/MyTapCount.xcodeproj" -scheme MyTapCount \
  -destination "id=$UDID" -configuration Debug -derivedDataPath "$DD" build >/dev/null
xcrun simctl install "$UDID" "$DD/Build/Products/Debug-iphonesimulator/MyTapCount.app"

xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi

rm -rf "$OUT"; mkdir -p "$OUT/ja" "$OUT/en-US"

shot() { # 1=出力先 2=言語 3=ロケール 4=画面(空ならホーム) 5=ファイル名
  xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
  python3 -c "import time;time.sleep(1)"
  if [ -n "$4" ]; then
    xcrun simctl launch "$UDID" "$BID" -AppleLanguages "($2)" -AppleLocale "$3" -seedSampleData -screen "$4" >/dev/null
  else
    xcrun simctl launch "$UDID" "$BID" -AppleLanguages "($2)" -AppleLocale "$3" -seedSampleData >/dev/null
  fi
  python3 -c "import time;time.sleep(5)"   # 描画とアニメーションの待ち
  xcrun simctl io "$UDID" screenshot "$OUT/$1/$5" >/dev/null 2>&1
  echo "  $1/$5"
}

for set_ in "ja ja ja_JP" "en-US en en_US"; do
  dir=${set_%% *}; rest=${set_#* }; lang=${rest%% *}; loc=${rest#* }
  echo "=== $dir ==="
  shot "$dir" "$lang" "$loc" ""         1_home.png
  shot "$dir" "$lang" "$loc" detail     2_detail.png
  shot "$dir" "$lang" "$loc" add        3_add.png
  shot "$dir" "$lang" "$loc" guide      4_guide.png
  shot "$dir" "$lang" "$loc" settings   5_settings.png
done

echo "=== サイズ確認 ==="
for f in "$OUT"/ja/*.png "$OUT"/en-US/*.png; do
  sips -g pixelWidth -g pixelHeight "$f" | tail -2 | tr -d ' \n' | sed "s|^|${f#$OUT/}  |;s/pixelWidth:/ /;s/pixelHeight:/x/"
  echo
done
