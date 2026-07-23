from PIL import Image

image = Image.open("app_icon.ico").convert("RGBA")
image.save(
    "setup_icon.ico",
    format="ICO",
    sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
)
