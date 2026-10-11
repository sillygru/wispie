"""Regenerates platform icons. Needs rsvg-convert and Pillow.

Layout: assets/icons/<id>/{source.svg|source.png, preview.png, window.png}.
`new` (the default) is built into every primary platform slot; `classic` is a
frozen raster whose native alternates were created once, so only its previews
and macOS imageset are regenerated. See assets/icons/README.md to add a variant.

Per-platform shaping: macOS gets an inset squircle with a soft shadow (the OS
does not mask), Windows/Linux get a rounded square, iOS gets a flat full-bleed
square (the OS masks), Android gets adaptive layers plus a rounded legacy icon.
"""
import os, re, subprocess
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
SVG = "assets/icons/new/source.svg"


def render(svg, px):
    subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), svg, "-o", "/tmp/_r.png"], check=True)
    return Image.open("/tmp/_r.png").convert("RGBA")


with open(SVG) as f:
    mark_svg = re.sub(r"<rect[^>]*/>", "", f.read())
with open("/tmp/_mark.svg", "w") as f:
    f.write(mark_svg)

SRC = {
    "new": render(SVG, 1024),
    "classic": Image.open("assets/icons/classic/source.png").convert("RGBA").resize((1024, 1024), Image.LANCZOS),
}
MARK = render("/tmp/_mark.svg", 1024)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def mask_rounded(size, frac):
    s = size * 4
    m = Image.new("L", (s, s), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, s - 1, s - 1), radius=int(s * frac), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def mask_squircle(size, n=5.0):
    s = size * 4
    pts = []
    import math
    for i in range(720):
        t = 2 * math.pi * i / 720
        c, sn = math.cos(t), math.sin(t)
        x = abs(c) ** (2 / n) * (1 if c >= 0 else -1)
        y = abs(sn) ** (2 / n) * (1 if sn >= 0 else -1)
        pts.append(((x + 1) / 2 * (s - 1), (y + 1) / 2 * (s - 1)))
    m = Image.new("L", (s, s), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def rounded(img, size, frac=0.2237):
    out = img.resize((size, size), Image.LANCZOS)
    out.putalpha(mask_rounded(size, frac))
    return out


def flat(img, size):
    out = img.resize((size, size), Image.LANCZOS)
    bg = Image.new("RGB", out.size, (0, 0, 0))
    bg.paste(out, mask=out.split()[3])
    return bg


def mac(img, size):
    # Apple template: 824px body in a 1024 canvas, shadow offset down.
    k = size / 1024
    body = round(824 * k)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    art = img.resize((body, body), Image.LANCZOS)
    m = mask_squircle(body)
    off = (size - body) // 2
    sh = Image.new("L", (size, size), 0)
    sh.paste(m, (off, off + round(10 * k)))
    sh = sh.filter(ImageFilter.GaussianBlur(max(1, 12 * k))).point(lambda v: int(v * 0.3))
    canvas.paste(Image.new("RGBA", (size, size), (0, 0, 0, 255)), mask=sh)
    art.putalpha(ImageChops.multiply(art.split()[3], m))
    canvas.alpha_composite(art, (off, off))
    return canvas


# Flutter-side previews and desktop window icons
for k in SRC:
    save(SRC[k].resize((512, 512), Image.LANCZOS), f"assets/icons/{k}/preview.png")
    save(rounded(SRC[k], 256), f"assets/icons/{k}/window.png")

# macOS
MA = "macos/Runner/Assets.xcassets"
for px in (16, 32, 64, 128, 256, 512, 1024):
    save(mac(SRC["new"], px), f"{MA}/AppIcon.appiconset/app_icon_{px}.png")
for k in SRC:
    save(mac(SRC[k], 512), f"{MA}/Icon{k.capitalize()}.imageset/icon.png")
    with open(f"{MA}/Icon{k.capitalize()}.imageset/Contents.json", "w") as f:
        f.write('{\n  "images" : [ { "filename" : "icon.png", "idiom" : "universal" } ],\n'
                '  "info" : { "author" : "xcode", "version" : 1 }\n}\n')

# iOS: flat, no alpha, the OS applies the mask
IA = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for fn in os.listdir(IA):
    m = re.match(r"Icon-App-([\d.]+)x[\d.]+@(\d)x\.png", fn)
    if m:
        px = round(float(m.group(1)) * int(m.group(2)))
        flat(SRC["new"], px).save(f"{IA}/{fn}")

# Windows
ico = rounded(SRC["new"], 256)
ico.save("windows/runner/resources/app_icon.ico", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])

# Linux hicolor
for d in os.listdir("packaging/linux/icons/hicolor"):
    px = int(d.split("x")[0])
    p = f"packaging/linux/icons/hicolor/{d}/apps/com.sillygru.wispie.png"
    if os.path.exists(p):
        rounded(SRC["new"], px).save(p)

# Android
R = "android/app/src/main/res"
dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
mark_bbox = MARK.getbbox()
mark = MARK.crop(mark_bbox)
for d, f in dens.items():
    fg_px, leg_px = round(108 * f), round(48 * f)
    # wordmark spans ~58% of the layer: inside the 66% adaptive safe zone
    w = round(fg_px * 0.58)
    mk = mark.resize((w, round(w * mark.height / mark.width)), Image.LANCZOS)
    fg = Image.new("RGBA", (fg_px, fg_px), (0, 0, 0, 0))
    fg.alpha_composite(mk, ((fg_px - mk.width) // 2, (fg_px - mk.height) // 2))
    save(fg, f"{R}/mipmap-{d}/ic_launcher_new_fg.png")
    mono = Image.new("RGBA", fg.size, (0, 0, 0, 0))
    mono.paste(Image.new("RGBA", fg.size, (255, 255, 255, 255)), mask=fg.split()[3])
    save(mono, f"{R}/mipmap-{d}/ic_launcher_new_mono.png")
    save(rounded(SRC["new"], leg_px, 0.18), f"{R}/mipmap-{d}/ic_launcher_new.png")
