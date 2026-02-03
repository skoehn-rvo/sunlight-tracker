#!/usr/bin/env python3
"""
Generate Sunlight Tracker app icon PNGs for macOS AppIcon.appiconset.
Requires: pip install Pillow
Run from repo root: python3 scripts/generate_app_icon.py
"""
from pathlib import Path
import math
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Install Pillow: pip install Pillow", file=sys.stderr)
    sys.exit(1)

OUT_DIR = Path(__file__).resolve().parent.parent / "SunlightTracker/Assets.xcassets/AppIcon.appiconset"
SIZES = [16, 32, 64, 128, 256, 512, 1024]
MASTER_SIZE = 1024


def draw_icon(size: int) -> Image.Image:
    """Draw the icon at the given pixel size. Warm sun on amber background."""
    scale = size / MASTER_SIZE
    radius = max(2, int(size * 0.18))

    # Background: single warm amber/orange, rounded rect
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=(220, 120, 50, 255))

    # Sun: center circle + 8 rays
    cx, cy = size * 0.5, size * 0.48
    r_sun = size * 0.26
    draw.ellipse(
        [cx - r_sun, cy - r_sun, cx + r_sun, cy + r_sun],
        fill=(255, 248, 220),
        outline=(255, 220, 150),
        width=max(1, int(2 * scale)),
    )
    ray_len = size * 0.4
    ray_width_deg = 20
    for i in range(8):
        angle_deg = i * 45
        angle_rad_lo = math.radians(angle_deg - ray_width_deg)
        angle_rad_hi = math.radians(angle_deg + ray_width_deg)
        x1 = cx + ray_len * math.cos(angle_rad_lo)
        y1 = cy - ray_len * math.sin(angle_rad_lo)
        x2 = cx + ray_len * math.cos(angle_rad_hi)
        y2 = cy - ray_len * math.sin(angle_rad_hi)
        draw.polygon([cx, cy, x1, y1, x2, y2], fill=(255, 230, 160))
    return img


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    master = draw_icon(MASTER_SIZE)
    for s in SIZES:
        if s == MASTER_SIZE:
            out = master
        else:
            out = master.resize((s, s), Image.Resampling.LANCZOS)
        out.save(OUT_DIR / f"icon_{s}.png", "PNG")
        print(f"Wrote icon_{s}.png")
    print("Done. Update Contents.json with filenames if not already set.")


if __name__ == "__main__":
    main()
