#!/usr/bin/env python3
"""
Generate a pink heart app icon for Lover's Compass.
Outputs a 1024x1024 PNG with a rose-to-deep-pink gradient background
and a centered white heart with subtle shadow.
"""

import os
import math

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    print("Installing Pillow...")
    os.system("pip3 install Pillow")
    from PIL import Image, ImageDraw, ImageFilter


def draw_heart(draw, cx, cy, size, fill):
    """Draw a heart shape centered at (cx, cy) with given size."""
    points = []
    for i in range(360):
        t = math.radians(i)
        # Heart parametric equations
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        # Scale and translate
        scale = size / 36.0
        px = cx + x * scale
        py = cy + y * scale
        points.append((px, py))
    draw.polygon(points, fill=fill)


def main():
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw gradient background (rose to deep pink)
    for y in range(size):
        ratio = y / size
        # Rose (255, 150, 175) -> Deep Pink (220, 50, 100)
        r = int(255 + (220 - 255) * ratio)
        g = int(150 + (50 - 150) * ratio)
        b = int(175 + (100 - 175) * ratio)
        draw.line([(0, y), (size - 1, y)], fill=(r, g, b, 255))

    # Round corners
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = int(size * 0.22)
    mask_draw.rounded_rectangle(
        [(0, 0), (size - 1, size - 1)],
        radius=corner_radius,
        fill=255,
    )
    img.putalpha(mask)

    # Draw shadow heart (offset down and slightly larger)
    shadow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_layer)
    draw_heart(shadow_draw, size // 2, size // 2 + 20, size * 0.55, (0, 0, 0, 60))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=20))
    img = Image.alpha_composite(img, shadow_layer)

    # Draw white heart
    heart_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    heart_draw = ImageDraw.Draw(heart_layer)
    draw_heart(heart_draw, size // 2, size // 2, size * 0.5, (255, 255, 255, 255))
    img = Image.alpha_composite(img, heart_layer)

    # Determine output path
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    output_dir = os.path.join(
        project_root,
        "LoversCompass",
        "LoversCompass",
        "Assets.xcassets",
        "AppIcon.appiconset",
    )
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "AppIcon-1024.png")

    # Flatten alpha for App Store (must be opaque)
    final = Image.new("RGB", (size, size), (255, 150, 175))
    final.paste(img, mask=img.split()[3])
    final.save(output_path, "PNG")
    print(f"Icon saved to: {output_path}")

    # Update Contents.json
    import json

    contents_path = os.path.join(output_dir, "Contents.json")
    contents = {
        "images": [
            {
                "filename": "AppIcon-1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"Contents.json updated: {contents_path}")


if __name__ == "__main__":
    main()
