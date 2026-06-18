from PIL import Image, ImageDraw, ImageFont
import os

sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

base_dir = "/home/claude/comicverse_app/android/app/src/main/res"
RED = (229, 9, 20, 255)
DARK = (11, 12, 16, 255)

def make_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), DARK)
    draw = ImageDraw.Draw(img)
    # دائرة حمراء مملوءة بهامش بسيط
    margin = int(size * 0.08)
    draw.ellipse([margin, margin, size - margin, size - margin], fill=RED)
    # حرف C أبيض في المنتصف (يرمز لـ Comicverse) عبر قوس بسيط بدل الاعتماد على خط قد لا يتوفر
    inner_margin = int(size * 0.27)
    bbox = [inner_margin, inner_margin, size - inner_margin, size - inner_margin]
    draw.arc(bbox, start=35, end=325, fill=(255, 255, 255, 255), width=max(2, int(size * 0.12)))
    return img

for folder, px in sizes.items():
    out_dir = os.path.join(base_dir, folder)
    os.makedirs(out_dir, exist_ok=True)
    icon = make_icon(px)
    icon.save(os.path.join(out_dir, "ic_launcher.png"))

print("Generated all launcher icons")
