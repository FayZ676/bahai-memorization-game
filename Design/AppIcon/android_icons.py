import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICONSET = os.path.join(ROOT, "MemorizationGame/Assets.xcassets/AppIcon.appiconset")
SPLASH = os.path.join(ROOT, "MemorizationGame/Assets.xcassets/SplashStar.imageset")
RES = os.path.join(ROOT, "android/app/src/main/res")
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
SAFE_ZONE = 66 / 108


def save(image, folder, name):
    path = os.path.join(RES, folder)
    os.makedirs(path, exist_ok=True)
    image.save(os.path.join(path, name), optimize=True)


def adaptive_layers(icon, size):
    background = icon.getpixel((4, 4))
    plate = Image.new("RGBA", (size, size), background)
    inner = round(size * SAFE_ZONE)
    plate.alpha_composite(icon.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2, (size - inner) // 2))
    return plate, background


def main():
    light = Image.open(os.path.join(ICONSET, "AppIcon.png")).convert("RGBA")
    dark = Image.open(os.path.join(ICONSET, "AppIcon-Dark.png")).convert("RGBA")
    for density, scale in DENSITIES.items():
        legacy = light.resize((round(48 * scale), round(48 * scale)), Image.LANCZOS)
        save(legacy, f"mipmap-{density}", "ic_launcher.png")
        save(legacy, f"mipmap-{density}", "ic_launcher_round.png")
        foreground, background = adaptive_layers(light, round(108 * scale))
        save(foreground, f"mipmap-{density}", "ic_launcher_foreground.png")
        night, _ = adaptive_layers(dark, round(108 * scale))
        save(night, f"mipmap-night-{density}", "ic_launcher_foreground.png")
    save(Image.open(os.path.join(SPLASH, "SplashStar.png")).resize((512, 512), Image.LANCZOS), "drawable-nodpi", "splash_star.png")
    save(Image.open(os.path.join(SPLASH, "SplashStar-Dark.png")).resize((512, 512), Image.LANCZOS), "drawable-night-nodpi", "splash_star.png")
    print("background", "#%02X%02X%02X" % background[:3])


if __name__ == "__main__":
    main()
