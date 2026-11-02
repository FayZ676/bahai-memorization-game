import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICONSET = os.path.join(ROOT, "MemorizationGame/Assets.xcassets/AppIcon.appiconset")
SPLASH = os.path.join(ROOT, "MemorizationGame/Assets.xcassets/SplashStar.imageset")
FONTS = os.path.join(ROOT, "MemorizationGame/Resources/Fonts")
OUT = os.path.join(ROOT, "android/store")
PAPER = (0xEC, 0xEE, 0xE8)
INK = (0x1C, 0x25, 0x21)
MUTED = (0x6A, 0x71, 0x6B)


def icon():
    Image.open(os.path.join(ICONSET, "AppIcon.png")).convert("RGBA").resize((512, 512), Image.LANCZOS).save(
        os.path.join(OUT, "play-icon-512.png"), optimize=True
    )


def feature_graphic():
    width, height = 1024, 500
    canvas = Image.new("RGB", (width, height), PAPER)
    star = Image.open(os.path.join(SPLASH, "SplashStar.png")).convert("RGBA").resize((340, 340), Image.LANCZOS)
    canvas.paste(star, (90, (height - 340) // 2), star)
    draw = ImageDraw.Draw(canvas)
    title = ImageFont.truetype(os.path.join(FONTS, "EBGaramond-SemiBold.ttf"), 112)
    subtitle = ImageFont.truetype(os.path.join(FONTS, "EBGaramond-Italic.ttf"), 46)
    draw.text((500, 158), "Verses", font=title, fill=INK)
    draw.text((504, 296), "Memorize Bahá’í prayers", font=subtitle, fill=MUTED)
    canvas.save(os.path.join(OUT, "feature-graphic.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icon()
    feature_graphic()
