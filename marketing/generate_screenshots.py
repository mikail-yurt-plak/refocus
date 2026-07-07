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
BG_TOP = (246, 248, 247)       # #F6F8F7
BG_BOTTOM = (214, 232, 227)    # gradyanın alt tonu
CAPTION_COLOR = "#173B34"      # koyu odak yeşili
DEVICE_WIDTH = 1060            # kasanın şablondaki genişliği
CAPTION_WIDTH = 1120
CAPTION_SIZE = 76
ICON_SIZE = 104

# Gerçek iPhone kasası (fastlane frameit çerçevesi) ve ekran penceresi
FRAME_PATH = ROOT / "frames" / "iphone-17-pro-max-silver.png"
FRAME_SCREEN_OFFSET = (75, 66)
FRAME_SCREEN_WIDTH = 1320

RTL_LOCALES = {"ar-SA", "ar"}


def gradient_background() -> Image.Image:
    img = Image.new("RGB", CANVAS, BG_TOP)
    draw = ImageDraw.Draw(img)
    for y in range(CANVAS[1]):
        t = y / CANVAS[1]
        color = tuple(int(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM))
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


def compose(raw_path: Path, caption_png: Path, out_path: Path) -> None:
    canvas = gradient_background().convert("RGBA")

    # Uygulama simgesi (üstte, küçük ve sakin)
    icon_path = ROOT.parent / "Sources/ReFocus/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png"
    if icon_path.exists():
        icon = Image.open(icon_path).convert("RGBA").resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
        icon.putalpha(icon.split()[3])
        mask = rounded_mask((ICON_SIZE, ICON_SIZE), ICON_SIZE // 4)
        canvas.paste(icon, ((CANVAS[0] - ICON_SIZE) // 2, 96), mask)

    # Başlık
    caption = Image.open(caption_png).convert("RGBA")
    if caption.width > CAPTION_WIDTH:
        ratio = CAPTION_WIDTH / caption.width
        caption = caption.resize((CAPTION_WIDTH, int(caption.height * ratio)), Image.LANCZOS)
    canvas.alpha_composite(caption, ((CANVAS[0] - caption.width) // 2, 252))
    caption_bottom = 252 + caption.height

    # Ham ekran görüntüsünü gerçek iPhone kasasına yerleştir
    frame = Image.open(FRAME_PATH).convert("RGBA")
    raw = Image.open(raw_path).convert("RGB")
    screen_h = int(FRAME_SCREEN_WIDTH * raw.height / raw.width)
    screen = raw.resize((FRAME_SCREEN_WIDTH, screen_h), Image.LANCZOS)

    framed = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    framed.paste(screen, FRAME_SCREEN_OFFSET)
    framed.alpha_composite(frame)  # kasa üstte: ekran pencere içinde kalır

    device_h = int(DEVICE_WIDTH * framed.height / framed.width)
    framed = framed.resize((DEVICE_WIDTH, device_h), Image.LANCZOS)
    device_x = (CANVAS[0] - DEVICE_WIDTH) // 2
    device_y = max(caption_bottom + 72, 560)

    # Kasa silüetinden yumuşak gölge
    silhouette = framed.split()[3].point(lambda a: min(a, 70))
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", framed.size, (20, 60, 50, 255)),
                 (device_x, device_y + 26), silhouette)
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    canvas.alpha_composite(shadow)

    canvas.alpha_composite(framed, (device_x, device_y))

    # Taşan kısmı kırp (cihaz alta taşarsa doğal görünür)
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
                jobs.append({
                    "text": captions[i],
                    "out": f"{tmp}/{i}.png",
                    "width": CAPTION_WIDTH,
                    "size": CAPTION_SIZE,
                    "color": CAPTION_COLOR,
                    "weight": "bold",
                })
            render_captions(jobs)

            for i, raw in enumerate(raws):
                out = ROOT / "store" / locale / "iphone-6.9" / f"screen-{i + 1}.png"
                compose(raw, Path(tmp) / f"{i}.png", out)
        print(f"tamam: {locale} ({len(raws)} görsel)")


if __name__ == "__main__":
    main()
