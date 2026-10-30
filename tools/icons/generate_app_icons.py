"""Regenerates every launcher icon on every platform from one source image.

    python3 tools/icons/generate_app_icons.py

The artwork lives in docs/brand/app-icon-source.png (1254px square). It is
drawn with its own rounded glass frame; phones put their own mask on top, so
the frame is cropped away and only the tile inside it becomes the icon.
Changing the icon means replacing that file and running this again.

What it writes:
  android/app/src/main/res/mipmap-*/ic_launcher.png             legacy, pre-26
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  adaptive
  android/app/src/main/res/mipmap-*/ic_launcher_background.png  adaptive
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png           every slot
  macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png
  windows/runner/resources/app_icon.ico
  web/icons/*.png, web/favicon.png
  docs/brand/app-icon-1024.png, docs/brand/play-store-512.png

iOS PNGs are written without an alpha channel: App Store validation rejects
an icon that carries one.

Needs Pillow and numpy.
"""

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/brand/app-icon-source.png"

# The square just inside the drawn frame, in source pixels.
CROP = (90, 90, 1162, 1162)

# Android's adaptive canvas is 108dp; only the middle 72dp is ever shown.
ADAPTIVE_DP = 108
SAFE_DP = 72
DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}


def load_art() -> Image.Image:
    return Image.open(SOURCE).convert("RGB").crop(CROP)


def resized(art: Image.Image, size: int) -> Image.Image:
    return art.resize((size, size), Image.LANCZOS)


def edge_padded(art: Image.Image, size: int, inner: int) -> Image.Image:
    """The art at `inner` px, centred on a `size` canvas whose margin repeats
    the art's edge pixels — so a launcher's parallax never shows a seam."""
    pixels = np.asarray(resized(art, inner))
    pad = (size - inner) // 2
    rest = size - inner - pad
    return Image.fromarray(np.pad(pixels, ((pad, rest), (pad, rest), (0, 0)), mode="edge"))


def rounded(img: Image.Image, radius_fraction: float) -> Image.Image:
    size = img.width
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1), radius=size * 4 * radius_fraction, fill=255
    )
    out = img.convert("RGBA")
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def save(img: Image.Image, rel: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def main() -> None:
    art = load_art()
    ground = tuple(int(c) for c in np.asarray(art).reshape(-1, 3).mean(axis=0))

    # Android — legacy square, then the adaptive layers.
    for name, scale in DENSITIES.items():
        res = f"android/app/src/main/res/mipmap-{name}"
        canvas = round(ADAPTIVE_DP * scale)
        save(resized(art, round(48 * scale)), f"{res}/ic_launcher.png")
        save(
            edge_padded(art, canvas, round(SAFE_DP * scale)),
            f"{res}/ic_launcher_foreground.png",
        )
        save(Image.new("RGB", (canvas, canvas), ground), f"{res}/ic_launcher_background.png")

    # iOS — one PNG per slot named in the asset catalogue, no alpha.
    catalogue = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    manifest = json.loads((ROOT / catalogue / "Contents.json").read_text())
    for entry in manifest["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        points = float(entry["size"].split("x")[0])
        scale = float(entry["scale"].rstrip("x"))
        save(resized(art, round(points * scale)), f"{catalogue}/{filename}")

    # macOS — the system does not mask these, so the corners are rounded here.
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save(
            rounded(resized(art, size), 0.225),
            f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png",
        )

    # Windows.
    rounded(resized(art, 256), 0.18).save(
        ROOT / "windows/runner/resources/app_icon.ico",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    # Web — the PWA slots plus the browser tab. Maskable slots are cropped to
    # their middle 80% by the browser, so the art is padded to survive it.
    save(resized(art, 192), "web/icons/Icon-192.png")
    save(resized(art, 512), "web/icons/Icon-512.png")
    save(edge_padded(art, 192, 154), "web/icons/Icon-maskable-192.png")
    save(edge_padded(art, 512, 410), "web/icons/Icon-maskable-512.png")
    save(rounded(resized(art, 64), 0.225), "web/favicon.png")

    # Store artwork.
    save(resized(art, 1024), "docs/brand/app-icon-1024.png")
    save(resized(art, 512), "docs/brand/play-store-512.png")


if __name__ == "__main__":
    main()
