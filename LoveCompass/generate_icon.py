"""
Generate a 1024x1024 app icon for Love Compass.
Pink-to-rose gradient background with a white compass-heart symbol.
Requires: pip install Pillow
"""

import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
CENTER = SIZE // 2

def create_gradient(size):
    """Create a radial gradient from rose-pink to deep rose."""
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)

    for y in range(size):
        for x in range(size):
            dx = x - CENTER
            dy = y - CENTER
            dist = math.sqrt(dx * dx + dy * dy) / (size * 0.7)
            dist = min(dist, 1.0)

            # From bright rose-pink center to deep rose edge
            r = int(255 * (1 - dist * 0.15))
            g = int(107 * (1 - dist * 0.6))
            b = int(138 * (1 - dist * 0.3))
            img.putpixel((x, y), (r, g, b))

    return img


def draw_heart(draw, cx, cy, scale, color):
    """Draw a heart shape centered at (cx, cy)."""
    points = []
    for i in range(360):
        t = math.radians(i)
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        points.append((cx + x * scale, cy + y * scale))
    draw.polygon(points, fill=color)


def draw_compass_needle(draw, cx, cy, length, width, color):
    """Draw a simple diamond-shaped compass needle pointing up."""
    points = [
        (cx, cy - length),       # top
        (cx + width, cy),        # right
        (cx, cy + length * 0.3), # bottom
        (cx - width, cy),        # left
    ]
    draw.polygon(points, fill=color)


def main():
    img = create_gradient(SIZE)
    draw = ImageDraw.Draw(img)

    # Draw a subtle outer ring
    ring_r = 420
    for angle in range(0, 360, 5):
        rad = math.radians(angle)
        x = CENTER + ring_r * math.cos(rad)
        y = CENTER + ring_r * math.sin(rad)
        dot_size = 6 if angle % 90 == 0 else 3
        draw.ellipse(
            [x - dot_size, y - dot_size, x + dot_size, y + dot_size],
            fill=(255, 255, 255, 180)
        )

    # Draw the main heart (white with slight transparency effect)
    draw_heart(draw, CENTER, CENTER + 20, 22, (255, 255, 255))

    # Draw a smaller pink heart inside for depth
    draw_heart(draw, CENTER, CENTER + 20, 14, (255, 140, 170))

    # Draw compass needle pointing up from center of heart
    draw_compass_needle(
        draw,
        CENTER, CENTER - 80,
        length=160, width=18,
        color=(255, 255, 255)
    )

    # Small circle at center
    draw.ellipse(
        [CENTER - 25, CENTER - 5, CENTER + 25, CENTER + 45],
        fill=(255, 255, 255)
    )

    # Inner pink dot
    draw.ellipse(
        [CENTER - 12, CENTER + 8, CENTER + 12, CENTER + 32],
        fill=(255, 100, 140)
    )

    output_path = "LoveCompass/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
    img.save(output_path, "PNG")
    print(f"Icon saved to {output_path}")


if __name__ == "__main__":
    main()
