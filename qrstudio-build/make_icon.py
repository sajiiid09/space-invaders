from PIL import Image, ImageDraw

canvas = Image.new("RGBA", (256, 256), (15, 23, 42, 255))
draw = ImageDraw.Draw(canvas)
draw.rounded_rectangle((22, 22, 234, 234), radius=34, fill=(31, 106, 165, 255))

# Clean QR-inspired white mark.
for x, y in ((52, 52), (156, 52), (52, 156)):
    draw.rounded_rectangle((x, y, x + 54, y + 54), radius=8, fill="white")
    draw.rounded_rectangle((x + 13, y + 13, x + 41, y + 41), radius=5, fill=(31, 106, 165, 255))

for x, y in ((136, 136), (168, 136), (200, 136), (136, 168), (200, 168), (168, 200), (200, 200)):
    draw.rounded_rectangle((x, y, x + 22, y + 22), radius=4, fill="white")

sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
for filename in ("app_icon.ico", "setup_icon.ico"):
    canvas.save(filename, format="ICO", sizes=sizes)
