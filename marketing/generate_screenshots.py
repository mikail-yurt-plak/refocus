#!/usr/bin/env python3
"""ReFocus App Store ekran görüntüsü üretici.

Ham uygulama ekran görüntülerini marka şablonuna yerleştirir:
gradyan zemin + dil bazında başlık + cihaz çerçevesi + yumuşak gölge.
Başlıklar, tüm yazı sistemlerini doğru şekillendirmek için macOS
CoreText ile render edilir (render_captions.swift).

Kullanım:
  python3 generate_screenshots.py                 # tüm dillerde üret
  python3 generate_screenshots.py --locales tr,en-US
  python3 generate_screenshots.py --placeholders  # ham görüntü yerine taslak üret

Girdiler:
  raw/1.png..6.png       Ham ekran görüntüleri (iPhone, herhangi bir boyut)
  metadata/store-copy-*.json  Dil bazında başlıklar ("captions")
Çıktı:
  store/<locale>/iphone-6.9/screen-<n>.png  (1290x2796)
"""

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).parent
CANVAS = (1290, 2796)          # iPhone 6.9" App Store boyutu
CAPTION_WIDTH = 1120
CAPTION_SIZE = 76
ICON_SIZE = 104

# Gerçek iPhone kasası (fastlane frameit çerçevesi) ve ekran penceresi
FRAME_PATH = ROOT / "frames" / "iphone-17-pro-max-silver.png"
FRAME_SCREEN_OFFSET = (75, 66)
FRAME_SCREEN_WIDTH = 1320
SCREEN_CORNER_RADIUS = 118     # ekranın yuvarlak köşeleri (beyaz taşmayı önler)

# Slayt stilleri: profesyonel setlerdeki gibi çeşitlilik.
# bg: light (marka gradyanı) / accent (koyu odak yeşili, beyaz başlık)
# device: full (tam cihaz) / peek (büyük, alttan kırpık)
# tilt: derece cinsinden hafif eğim
LIGHT_TOP, LIGHT_BOTTOM = (246, 248, 247), (214, 232, 227)
ACCENT_TOP, ACCENT_BOTTOM = (46, 125, 111), (23, 59, 52)
SLIDE_STYLES = [
    {"bg": "accent", "device": "full", "tilt": 0},   # 1: kanca — marka rengi
    {"bg": "light", "device": "peek", "tilt": 0},    # 2: büyük cihaz, alttan kırpık
    {"bg": "light", "device": "peek", "tilt": -6},   # 3: hafif eğik
    {"bg": "light", "device": "full", "tilt": 0},    # 4: sakin tam cihaz
    {"bg": "accent", "device": "peek", "tilt": 0},   # 5: vurgu + kırpık
    {"bg": "light", "device": "full", "tilt": 0},    # 6: sade kapanış
]

RTL_LOCALES = {"ar-SA", "ar"}


def gradient_background(style: str) -> Image.Image:
    top, bottom = (ACCENT_TOP, ACCENT_BOTTOM) if style == "accent" else (LIGHT_TOP, LIGHT_BOTTOM)
    img = Image.new("RGB", CANVAS, top)
    draw = ImageDraw.Draw(img)
    for y in range(CANVAS[1]):
        t = y / CANVAS[1]
        color = tuple(int(a + (b - a) * t) for a, b in zip(top, bottom))
        draw.line([(0, y), (CANVAS[0], y)], fill=color)
    return img


def rounded_mask(size, radius) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0], size[1]], radius=radius, fill=255)
    return mask


def render_captions(jobs: list) -> None:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(jobs, f, ensure_ascii=False)
        path = f.name
    subprocess.run(["swift", str(ROOT / "render_captions.swift"), path],
                   check=True, capture_output=True)


def framed_device(raw_path: Path) -> Image.Image:
    """Ham ekran görüntüsünü gerçek iPhone kasasına yerleştirir.
    Ekran, kasanın penceresine yuvarlak köşeli maskeyle oturur —
    köşelerden beyaz taşma olmaz."""
    frame = Image.open(FRAME_PATH).convert("RGBA")
    raw = Image.open(raw_path).convert("RGB")
    screen_h = int(FRAME_SCREEN_WIDTH * raw.height / raw.width)
    screen = raw.resize((FRAME_SCREEN_WIDTH, screen_h), Image.LANCZOS)

    framed = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    framed.paste(screen, FRAME_SCREEN_OFFSET,
                 rounded_mask(screen.size, SCREEN_CORNER_RADIUS))
    framed.alpha_composite(frame)
    return framed


def compose(raw_path: Path, caption_png: Path, out_path: Path, style: dict) -> None:
    canvas = gradient_background(style["bg"]).convert("RGBA")
    is_accent = style["bg"] == "accent"

    # Uygulama simgesi (açık zeminli slaytlarda, üstte küçük ve sakin)
    caption_top = 252
    if not is_accent:
        icon_path = ROOT.parent / "Sources/ReFocus/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png"
        if icon_path.exists():
            icon = Image.open(icon_path).convert("RGBA").resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
            mask = rounded_mask((ICON_SIZE, ICON_SIZE), ICON_SIZE // 4)
            canvas.paste(icon, ((CANVAS[0] - ICON_SIZE) // 2, 96), mask)
    else:
        caption_top = 200

    # Başlık
    caption = Image.open(caption_png).convert("RGBA")
    if caption.width > CAPTION_WIDTH:
        ratio = CAPTION_WIDTH / caption.width
        caption = caption.resize((CAPTION_WIDTH, int(caption.height * ratio)), Image.LANCZOS)
    canvas.alpha_composite(caption, ((CANVAS[0] - caption.width) // 2, caption_top))
    caption_bottom = caption_top + caption.height

    # Cihaz: stiline göre boyut, eğim ve kırpma
    framed = framed_device(raw_path)
    device_width = 1150 if style["device"] == "peek" else 1060
    device_h = int(device_width * framed.height / framed.width)
    framed = framed.resize((device_width, device_h), Image.LANCZOS)

    if style["tilt"]:
        framed = framed.rotate(style["tilt"], expand=True,
                               resample=Image.BICUBIC)

    device_x = (CANVAS[0] - framed.width) // 2
    device_y = max(caption_bottom + 72, 520 if style["device"] == "peek" else 560)

    # Kasa silüetinden yumuşak gölge
    shadow_color = (0, 0, 0, 255) if is_accent else (20, 60, 50, 255)
    silhouette = framed.split()[3].point(lambda a: min(a, 80))
    shadow = Image.new("RGBA",
                       (CANVAS[0], max(CANVAS[1], device_y + framed.height + 80)),
                       (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", framed.size, shadow_color),
                 (device_x, device_y + 26), silhouette)
    shadow = shadow.filter(ImageFilter.GaussianBlur(36)).crop((0, 0, *CANVAS))
    canvas.alpha_composite(shadow)

    # Cihazı yerleştir; peek stilinde alt kısım tuval dışında kalır
    visible_h = min(framed.height, CANVAS[1] - device_y)
    canvas.alpha_composite(framed.crop((0, 0, framed.width, visible_h)),
                           (device_x, device_y))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path)


def make_placeholders(raw_dir: Path) -> None:
    """Ham görüntüler henüz yokken şablonu denemek için taslak ekranlar üretir."""
    raw_dir.mkdir(parents=True, exist_ok=True)
    labels = ["Ana Ekran", "Odak", "Niyet Seçimi", "Geçmiş", "Arkadaşlar", "iCloud"]
    for i, label in enumerate(labels, 1):
        img = Image.new("RGB", (1170, 2532), (246, 248, 247))
        draw = ImageDraw.Draw(img)
        cx, cy = 585, 1100
        for r, col in [(400, (217, 232, 228)), (315, (186, 213, 207)), (235, (143, 188, 178)),
                       (158, (92, 157, 145)), (85, (46, 125, 111))]:
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
        draw.text((cx, 2100), f"{i}. {label}", fill=(107, 107, 107), anchor="mm")
        img.save(raw_dir / f"{i}.png")


def load_captions() -> dict:
    merged = {}
    for f in sorted((ROOT / "metadata").glob("store-copy-*.json")):
        merged.update(json.loads(f.read_text()))
    return merged


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--locales", default=None)
    parser.add_argument("--placeholders", action="store_true")
    args = parser.parse_args()

    raw_dir = ROOT / "raw"
    if args.placeholders:
        make_placeholders(raw_dir)

    all_captions = load_captions()
    locales = args.locales.split(",") if args.locales else list(all_captions)

    for locale in locales:
        entry = all_captions.get(locale)
        if not entry:
            print(f"atlandı (metin yok): {locale}")
            continue
        captions = entry["captions"]

        # Öncelik: simülatörden dil bazında çekilen görüntüler;
        # yoksa ortak raw/ klasörü
        locale_raw = ROOT / "raw-sim" / locale
        raws = sorted(locale_raw.glob("[0-9].png")) or sorted(raw_dir.glob("[0-9].png"))
        if not raws:
            sys.exit(f"Ham görüntü yok ({locale}): raw-sim/{locale}/ veya raw/ bekleniyor")

        with tempfile.TemporaryDirectory() as tmp:
            jobs = []
            for i in range(len(raws)):
                style = SLIDE_STYLES[i % len(SLIDE_STYLES)]
                jobs.append({
                    "text": captions[i],
                    "out": f"{tmp}/{i}.png",
                    "width": CAPTION_WIDTH,
                    "size": CAPTION_SIZE,
                    "color": "#FFFFFF" if style["bg"] == "accent" else "#173B34",
                    "weight": "bold",
                })
            render_captions(jobs)

            for i, raw in enumerate(raws):
                out = ROOT / "store" / locale / "iphone-6.9" / f"screen-{i + 1}.png"
                compose(raw, Path(tmp) / f"{i}.png", out,
                        SLIDE_STYLES[i % len(SLIDE_STYLES)])
        print(f"tamam: {locale} ({len(raws)} görsel)")


if __name__ == "__main__":
    main()
