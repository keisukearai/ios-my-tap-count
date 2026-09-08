#!/usr/bin/env python3
"""AppIcon 候補を 1024x1024 で書き出す。

デザイン（MyTapCount.dc.html）の配色をそのまま使う。
App Store 提出用アイコンはアルファ不可なので RGB で保存する。
角丸は OS が付けるため、ここでは全面を塗る。

  python3 Design/AppIcon/make_icons.py
"""

from PIL import Image, ImageDraw

S = 1024          # 最終サイズ
SS = 4            # スーパーサンプリング倍率（縁のギザつきを消す）
N = S * SS

ACCENT      = (0x2F, 0x7D, 0x4F)
ACCENT_DEEP = (0x1D, 0x5E, 0x3B)
CANVAS      = (0xF2, 0xF4, 0xF7)
INK         = (0x16, 0x18, 0x1C)
INK_LIFT    = (0x25, 0x28, 0x2E)   # インク地のグラデーション先
ACCENT_LIT  = (0x3E, 0x9E, 0x64)   # 暗い地に載せる緑。accent のままだと 60px で沈む
BLUE        = (0x2F, 0x6F, 0xD0)
BLUE_DEEP   = (0x22, 0x4E, 0x96)
TRACK_LIGHT = (0xDD, 0xE1, 0xE6)   # 明るい地に置くリングの土台
WHITE       = (0xFF, 0xFF, 0xFF)


def canvas(fill):
    img = Image.new("RGB", (N, N), fill)
    return img, ImageDraw.Draw(img)


def diagonal_gradient(img, top, bottom):
    """左上→右下の緩いグラデーション。単色より奥行きが出る。"""
    grad = Image.new("RGB", (N, N))
    px = grad.load()
    for y in range(N):
        for x in range(0, N, 64):          # 横方向は粗くて十分
            t = (x / N * 0.35 + y / N * 0.65)
            c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
            for dx in range(64):
                if x + dx < N:
                    px[x + dx, y] = c
    img.paste(grad)


def plus(draw, cx, cy, arm, thick, color):
    r = thick / 2
    draw.rounded_rectangle([cx - arm, cy - r, cx + arm, cy + r], radius=r, fill=color)
    draw.rounded_rectangle([cx - r, cy - arm, cx + r, cy + arm], radius=r, fill=color)


def capped_line(draw, p0, p1, thick, color):
    """丸い端点を持つ線。PIL の line は角が立つので円を足す。"""
    draw.line([p0, p1], fill=color, width=int(thick))
    r = thick / 2
    for (x, y) in (p0, p1):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def save(img, name):
    out = img.resize((S, S), Image.LANCZOS)
    path = f"Design/AppIcon/{name}.png"
    out.save(path, "PNG")
    print("wrote", path)


# ── 1: ＋ ─────────────────────────────────────────────
# ウィジェットの ＋ ボタンそのもの。アプリの動作を1つの記号で言い切る。
def icon_plus():
    img, d = canvas(ACCENT)
    diagonal_gradient(img, ACCENT, ACCENT_DEEP)
    d = ImageDraw.Draw(img)
    c = N / 2
    plus(d, c, c, arm=N * 0.255, thick=N * 0.145, color=WHITE)
    save(img, "candidate-1-plus")


# ── 2: タリー ────────────────────────────────────────
# 「回数を数える」を直接表す。数字を使わないので多言語でも読める。
# 5本は小さいサイズで潰れやすいので、線を太くして間隔を空けている。
def icon_tally():
    img, d = canvas(ACCENT)
    diagonal_gradient(img, ACCENT, ACCENT_DEEP)
    d = ImageDraw.Draw(img)
    thick = N * 0.086
    r = thick / 2
    top, bot = N * 0.300, N * 0.700
    xs = [N * 0.318, N * 0.446, N * 0.574, N * 0.702]
    for x in xs:
        d.rounded_rectangle([x - r, top, x + r, bot], radius=r, fill=WHITE)
    capped_line(d, (N * 0.262, N * 0.652), (N * 0.758, N * 0.348), thick, WHITE)
    save(img, "candidate-2-tally")


# ── 3: 目標リング ────────────────────────────────────
# 1日の目標に対する進み具合。中央の ＋ で「押して増やす」ことも示す。
# 目盛りは 60px で潰れたので落とし、リングを太くして輪郭だけ残した。
def icon_ring():
    import math
    img, _ = canvas(ACCENT)
    diagonal_gradient(img, ACCENT, ACCENT_DEEP)

    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = N / 2
    radius = N * 0.305
    thick = N * 0.105
    box = [c - radius, c - radius, c + radius, c + radius]

    d.arc(box, 0, 360, fill=(255, 255, 255, 58), width=int(thick))

    # 端は丸めない。丸めると 60px で玉に見えて、進捗の切れ目が読めなくなる。
    start, sweep = -96, 258                      # 7/10 ほど進んだ状態
    d.arc(box, start, start + sweep, fill=(255, 255, 255, 255), width=int(thick))

    plus(d, c, c, arm=N * 0.125, thick=N * 0.070, color=(255, 255, 255, 255))

    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    save(img, "candidate-3-ring")



# ── 3 の色違い（4〜6） ───────────────────────────────
# 構図は candidate-3 のまま、地とリングの色だけ変える。
def ring_icon(name, ground_top, ground_bottom, track, arc, plus_color):
    import math
    img, _ = canvas(ground_top)
    diagonal_gradient(img, ground_top, ground_bottom)

    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = N / 2
    radius = N * 0.305
    thick = N * 0.105
    box = [c - radius, c - radius, c + radius, c + radius]

    d.arc(box, 0, 360, fill=track, width=int(thick))
    d.arc(box, -96, -96 + 258, fill=arc, width=int(thick))
    plus(d, c, c, arm=N * 0.125, thick=N * 0.070, color=plus_color)

    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    save(img, name)


def icon_ring_ink():
    """4: インク地。緑が最も締まって見え、ホーム画面でも埋もれない。"""
    ring_icon("candidate-4-ring-ink",
              INK, INK_LIFT,
              track=(255, 255, 255, 40),
              arc=ACCENT_LIT + (255,),
              plus_color=(255, 255, 255, 255))


def icon_ring_light():
    """5: ライト地。暗いアイコンが並ぶ中で白く抜ける。アプリ内の canvas と同じ地。"""
    ring_icon("candidate-5-ring-light",
              WHITE, CANVAS,
              track=TRACK_LIGHT + (255,),
              arc=ACCENT + (255,),
              plus_color=ACCENT + (255,))


def icon_ring_blue():
    """6: ブルー地。緑の医療っぽさを避けたい場合。色は一覧の「水」と同じ #2F6FD0。"""
    ring_icon("candidate-6-ring-blue",
              BLUE, BLUE_DEEP,
              track=(255, 255, 255, 58),
              arc=(255, 255, 255, 255),
              plus_color=(255, 255, 255, 255))



# ── 採用案の書き出し（candidate-4 / インク地のリング） ──────────
# iOS 18 以降のアイコンは light / dark / tinted の3枚組。
# dark と tinted は「地を持たない」のが決まりで、背景は OS が描く。
# tinted はグレースケールで渡し、色は OS が乗せる。
ICONSET = "MyTapCount/Assets.xcassets/AppIcon.appiconset"


def ring_glyph(layer_size, track, arc, plus_color):
    """リングと ＋ だけを RGBA で描く。地は呼び出し側の責任。"""
    import math
    layer = Image.new("RGBA", (layer_size, layer_size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = layer_size / 2
    radius = layer_size * 0.305
    thick = layer_size * 0.105
    box = [c - radius, c - radius, c + radius, c + radius]
    d.arc(box, 0, 360, fill=track, width=int(thick))
    d.arc(box, -96, -96 + 258, fill=arc, width=int(thick))
    plus(d, c, c, arm=layer_size * 0.125, thick=layer_size * 0.070, color=plus_color)
    return layer


def write_appicon():
    import json, os

    # light: 地あり。App Store 提出用なのでアルファを持たせない。
    light, _ = canvas(INK)
    diagonal_gradient(light, INK, INK_LIFT)
    glyph = ring_glyph(N, (255, 255, 255, 40), ACCENT_LIT + (255,), (255, 255, 255, 255))
    light = Image.alpha_composite(light.convert("RGBA"), glyph).convert("RGB")
    light.resize((S, S), Image.LANCZOS).save(f"{ICONSET}/AppIcon-1024.png", "PNG")

    # dark: 地なし。OS が暗い背景を敷く。
    dark = ring_glyph(N, (255, 255, 255, 40), ACCENT_LIT + (255,), (255, 255, 255, 255))
    dark.resize((S, S), Image.LANCZOS).save(f"{ICONSET}/AppIcon-Dark-1024.png", "PNG")

    # tinted: 地なしのグレースケール。明るいところほど濃く着色される。
    tinted = ring_glyph(N, (255, 255, 255, 64), (255, 255, 255, 255), (255, 255, 255, 255))
    tinted.resize((S, S), Image.LANCZOS).save(f"{ICONSET}/AppIcon-Tinted-1024.png", "PNG")

    contents = {
        "images": [
            {"filename": "AppIcon-1024.png", "idiom": "universal",
             "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}],
             "filename": "AppIcon-Dark-1024.png", "idiom": "universal",
             "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "tinted"}],
             "filename": "AppIcon-Tinted-1024.png", "idiom": "universal",
             "platform": "ios", "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(f"{ICONSET}/Contents.json", "w") as f:
        json.dump(contents, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("applied candidate-4 to", ICONSET)


if __name__ == "__main__":
    import sys
    if "--apply" in sys.argv:
        write_appicon()
        raise SystemExit

    icon_plus()
    icon_tally()
    icon_ring()
    icon_ring_ink()
    icon_ring_light()
    icon_ring_blue()
