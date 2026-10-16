# -*- coding: utf-8 -*-
"""生成 HarmonyMall app_icon.png：蓝色圆角底 + 白色购物袋图形（192x192，纯代码绘制，非 AI 生成）"""
from PIL import Image, ImageDraw

SIZE = 192
OUT = "app_icon.png"

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# ---- 1. 圆角方形底：竖向渐变蓝（上浅下深） ----
top = (41, 128, 240, 255)    # 亮蓝
bottom = (23, 93, 200, 255)  # 深蓝
radius = 42
grad = Image.new("RGBA", (SIZE, SIZE))
gd = ImageDraw.Draw(grad)
for y in range(SIZE):
    t = y / (SIZE - 1)
    c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4))
    gd.line([(0, y), (SIZE, y)], fill=c)

mask = Image.new("L", (SIZE, SIZE), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=radius, fill=255)
img.paste(grad, (0, 0), mask)
d = ImageDraw.Draw(img)

# ---- 2. 购物袋袋身（白色，圆角梯形） ----
# 袋身：从 x=52..140，y=76..142，圆角
d.rounded_rectangle([52, 78, 140, 142], radius=10, fill=(255, 255, 255, 255))

# ---- 3. 提手（白色描边圆弧） ----
# 提手是两个半圆弧，用宽线绘制
handle_color = (255, 255, 255, 255)
# 左提手
d.arc([70, 52, 98, 84], start=180, end=360, fill=handle_color, width=9)
# 右提手
d.arc([94, 52, 122, 84], start=180, end=360, fill=handle_color, width=9)

# ---- 4. 袋身点缀：两个蓝色小圆点 + 横线，暗示商品/货架 ----
blue = (23, 93, 200, 255)
d.ellipse([72, 96, 84, 108], fill=blue)
d.ellipse([100, 96, 112, 108], fill=blue)
d.rounded_rectangle([76, 118, 116, 126], radius=4, fill=blue)

img.save(OUT, "PNG")
print("saved", OUT, img.size)
