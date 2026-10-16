# -*- coding: utf-8 -*-
"""HarmonyMall 数据补充脚本：新增商品 + 新增/修复轮播图（数据源：网易严选公开接口）

与 crawl_products.py 的区别——**增量补充，不重建 data.sql**：
  1. 不影响已有的订单 / 购物车 / 地址 / 收藏等业务数据
  2. 商品去重：已有图片文件名 item_<严选ID>.<ext> 记录了已经抓过的商品，逐个跳过
  3. 轮播图只接受"宽幅图"（宽高比 >= 2.2），方形/竖图（商品主图）一律丢弃
     —— 之前误抓了一张 800x800 的行李箱主图当横幅，在手机宽幅位上被裁成一条，这就是轮播图显示异常的根因

轮播图归一到统一比例 TARGET_RATIO = 2.8（手机上 Swiper 用 aspectRatio(2.8) 展示，端上零裁切）：
  - 比目标更宽：上下边缘背景平坦 → 用边缘逐列颜色上下延展（完全不裁内容）
               边缘不平坦（商品压到底边） → 从右侧裁（保住左侧文案，只裁右边商品）
  - 比目标更窄：左右边缘背景平坦 → 用边缘逐行颜色左右延展
"""
import hashlib
import html
import json
import os
import re
import ssl
import subprocess
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image

ROOT = r"C:\Users\95108\IdeaProjects\harmonymall-server"
IMG_PRODUCTS = os.path.join(ROOT, "src/main/resources/static/img/products")
IMG_BANNER = os.path.join(ROOT, "src/main/resources/static/img/banner")
SQL_OUT = os.path.join(ROOT, "src/main/resources/db/add_products.sql")

MYSQL = r"D:\Mysql\MySQL Server 8.0\bin\mysql.exe"
DB = "harmonymall"

TARGET_RATIO = 2.8           # 横幅目标宽高比
MIN_BANNER_RATIO = 2.2       # 低于此值不算横幅（商品主图都是 1:1）
MAX_PER_KEYWORD = 2          # 每个关键词最多取几个新商品
NEW_BANNERS = 3              # 除替换方形图外，额外新增的横幅数

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

# 二级分类 ID -> (目标商品总数, 补充用关键词列表)
PLAN = [
    (5, 7, ["蓝牙耳机", "头戴式耳机", "入耳式耳机"]),
    (6, 7, ["智能手环", "运动手表", "智能体脂秤", "智能眼镜"]),
    (7, 9, ["显示器", "无线鼠标", "移动电源"]),
    (8, 7, ["衬衫", "针织衫", "POLO衫"]),
    (9, 7, ["羽绒服", "夹克", "冲锋衣"]),
    (10, 7, ["帆布鞋", "休闲鞋", "板鞋"]),
    (11, 7, ["单肩包", "行李箱", "帽子"]),
    (12, 7, ["水杯", "餐具", "咖啡杯"]),
    (13, 7, ["落地灯", "小夜灯", "氛围灯"]),
    (14, 7, ["电风扇", "空气净化器", "电吹风"]),
    (15, 7, ["枕头", "被子", "毛毯"]),
    (16, 9, ["抱枕", "雨伞", "洗衣液"]),
    (17, 5, ["文具盒", "打印纸", "笔筒"]),
]


def log(msg):
    print(msg, flush=True)


# ---------------------------------------------------------------- HTTP

def http_get(url, retry=2):
    for attempt in range(retry):
        try:
            req = urllib.request.Request(url, headers={
                "User-Agent": UA,
                "Accept": "application/json,text/html,*/*",
                "Referer": "https://you.163.com/",
            })
            with urllib.request.urlopen(req, timeout=20, context=CTX) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except Exception:
            if attempt == retry - 1:
                raise
            time.sleep(1.0)


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": "https://you.163.com/"})
    with urllib.request.urlopen(req, timeout=30, context=CTX) as resp:
        data = resp.read()
    if len(data) < 1024:
        raise ValueError("too small: " + url)
    with open(dest, "wb") as f:
        f.write(data)
    return len(data)


def ext_of(url):
    m = re.search(r"\.(png|jpg|jpeg|webp)(?:\?|$)", url, re.I)
    return "." + (m.group(1).lower() if m else "jpg")


def fetch_keyword(keyword):
    url = ("https://you.163.com/xhr/search/search.json?keyword="
           + urllib.parse.quote(keyword)
           + "&page=1&sortType=0&descSorted=false&categoryId=0&matchType=0")
    data = http_get(url)
    directly = (data or {}).get("data", {}).get("directly", {}) or {}
    items = (directly.get("searcherResult", {}) or {}).get("result", []) or []
    hits = directly.get("searcherCategoryHitCountList", []) or []
    return items, hits


# ---------------------------------------------------------------- DB

def mysql(sql, plain=True):
    args = [MYSQL, "-uroot", "-p123456", "--default-character-set=utf8mb4", "-D", DB]
    if plain:
        args.append("-N")
        args.append("-B")
    args += ["-e", sql]
    out = subprocess.run(args, capture_output=True, text=True, encoding="utf-8")
    if out.returncode != 0:
        raise RuntimeError("mysql failed: " + (out.stderr or "")[:300])
    return out.stdout.strip()


def esc(s):
    return (s or "").replace("\\", "\\\\").replace("'", "''")


def clean_name(name):
    name = re.sub(r"^【[^】]*】", "", name or "").strip()
    return re.sub(r"\s+", " ", name)[:90]


def related(name, keyword):
    """粗校验搜索结果是否和关键词沾边

    严选的搜索是模糊匹配，曾出现"小夜灯"搜出"SK-II 小灯泡精华"这类杂质。
    规则：关键词的最后两个字必须出现在商品名里（"小夜灯" -> "夜灯"）。
    """
    key = keyword[-2:] if len(keyword) >= 2 else keyword
    return key in (name or "")


def sku_specs(sku):
    specs = {}
    for pair in sku.get("itemSkuSpecValueList", []) or sku.get("itemSkuValueList", []) or []:
        spec = pair.get("skuSpec") or {}
        val = pair.get("skuSpecValue") or {}
        if spec.get("name") and val.get("value"):
            specs[spec["name"]] = val["value"]
    return specs


# ---------------------------------------------------------------- 轮播图归一

def edge_flat(im, rows=5, tol=12):
    """上下边缘是否为平坦背景（逐列颜色偏差 <= tol）"""
    w, h = im.size
    for box in ((0, 0, w, rows), (0, h - rows, w, h)):
        strip = im.crop(box)
        px = list(strip.getdata())
        avg = tuple(sum(c[i] for c in px) // len(px) for i in range(3))
        for x in range(w):
            col = [strip.getpixel((x, y)) for y in range(rows)]
            ca = tuple(sum(c[i] for c in col) // rows for i in range(3))
            if max(abs(ca[i] - avg[i]) for i in range(3)) > tol:
                return False
    return True


def pad_vertical(im, ratio):
    """用上下边缘的逐列颜色上下延展到目标比例（不裁内容）"""
    w, h = im.size
    new_h = int(round(w / ratio))
    pad = new_h - h
    top = pad // 2
    bot = pad - top
    canvas = Image.new("RGB", (w, new_h))
    if top > 0:
        canvas.paste(im.crop((0, 0, w, 1)).resize((w, top), Image.NEAREST), (0, 0))
    canvas.paste(im, (0, top))
    if bot > 0:
        canvas.paste(im.crop((0, h - 1, w, h)).resize((w, bot), Image.NEAREST), (0, top + h))
    return canvas


def pad_horizontal(im, ratio):
    """用左右边缘的逐行颜色左右延展到目标比例"""
    w, h = im.size
    new_w = int(round(h * ratio))
    pad = new_w - w
    left = pad // 2
    right = pad - left
    canvas = Image.new("RGB", (new_w, h))
    if left > 0:
        canvas.paste(im.crop((0, 0, 1, h)).resize((left, h), Image.NEAREST), (0, 0))
    canvas.paste(im, (left, 0))
    if right > 0:
        canvas.paste(im.crop((w - 1, 0, w, h)).resize((right, h), Image.NEAREST), (left + w, 0))
    return canvas


def normalize_banner(path):
    """把横幅归一到 TARGET_RATIO，返回处理方式说明

    优先级：
      1. 上下边缘都是平坦背景 → 上下补背景（完全不裁内容，最佳）
      2. 需要裁掉的宽度超过 15% → 也补背景（内容完整性优先，补背景的轻微接缝比切掉促销文案更容易接受）
      3. 只需裁一点点（< 15%）→ 从右侧裁（保住左侧文案，只裁右边商品出框）
    """
    im = Image.open(path).convert("RGB")
    w, h = im.size
    ratio = w / h
    if abs(ratio - TARGET_RATIO) < 0.02:
        return "already %.2f（未改动）" % ratio
    if ratio > TARGET_RATIO:
        crop_ratio = 1 - TARGET_RATIO / ratio
        if edge_flat(im) or crop_ratio > 0.15:
            pad_vertical(im, TARGET_RATIO).save(path, quality=90)
            return "%.2f -> 上下补背景(未裁内容)" % ratio
        new_w = int(round(h * TARGET_RATIO))
        im.crop((0, 0, new_w, h)).save(path, quality=90)
        return "%.2f -> 右侧裁 %.0f%%(保住左侧文案)" % (ratio, crop_ratio * 100)
    pad_horizontal(im, TARGET_RATIO).save(path, quality=90)
    return "%.2f -> 左右补背景" % ratio


# ---------------------------------------------------------------- main

def main():
    no_banners = "--no-banners" in sys.argv
    os.makedirs(IMG_PRODUCTS, exist_ok=True)
    os.makedirs(IMG_BANNER, exist_ok=True)

    # 1) 已有商品（用图片文件名里的严选 ID 去重）
    seen = set()
    for f in os.listdir(IMG_PRODUCTS):
        m = re.match(r"item_(\d+)\.\w+$", f)
        if m:
            seen.add(m.group(1))
    log("== 已有商品图 %d 张，严选 ID 去重表 %d 个" % (len(os.listdir(IMG_PRODUCTS)), len(seen)))

    cur_total = int(mysql("SELECT COUNT(*) FROM t_product;"))
    max_pid = int(mysql("SELECT IFNULL(MAX(id),0) FROM t_product;"))
    max_sku = int(mysql("SELECT IFNULL(MAX(id),0) FROM t_product_sku;"))
    per_cat = {}
    for row in mysql("SELECT category_id, COUNT(*) FROM t_product GROUP BY category_id;").splitlines():
        cid, cnt = row.split("\t")
        per_cat[int(cid)] = int(cnt)
    log("== 当前商品 %d 个（最大 ID %d，最大 SKU ID %d）" % (cur_total, max_pid, max_sku))

    # 2) 抓商品
    log("== 爬取新商品 ...")
    new_products = []
    banner_urls = []
    for cid, target, keywords in PLAN:
        have = per_cat.get(cid, 0)
        need = max(0, target - have)
        if need == 0:
            log("   分类 %-3d 已有 %d 个，跳过" % (cid, have))
            continue
        got = 0
        for kw in keywords:
            if got >= need:
                break
            try:
                items, hits = fetch_keyword(kw)
            except Exception as e:
                log("   [warn] 关键词 %s 失败: %r" % (kw, e))
                continue
            for cat in hits:
                vo = cat.get("categoryVO") or {}
                b = vo.get("bannerUrl")
                if b and b not in banner_urls:
                    banner_urls.append(b)
            taken = 0
            for item in items:
                if taken >= MAX_PER_KEYWORD or got >= need:
                    break
                if item.get("soldOut") or item.get("underShelf"):
                    continue
                iid = item.get("id")
                price = item.get("retailPrice")
                name = clean_name(item.get("name"))
                if not iid or str(iid) in seen or not price or price <= 0 or not name:
                    continue
                if not related(name, kw):
                    log("   [skip] %s 与关键词「%s」不相关，丢弃" % (name[:24], kw))
                    continue
                img_url = item.get("listPicUrl") or item.get("primaryPicUrl")
                if not img_url:
                    continue
                seen.add(str(iid))
                new_products.append({
                    "yid": iid, "name": name,
                    "desc": (item.get("simpleDesc") or "").strip(),
                    "price_yuan": float(price),
                    "counter_yuan": float(item.get("counterPrice") or 0),
                    "image_url": img_url,
                    "category_id": cid,
                    "skus": item.get("skuList") or [],
                })
                taken += 1
                got += 1
            log("   分类 %-3d 关键词 %-8s 取 %d 个（本类合计 %d/%d）" % (cid, kw, taken, got, need))
            time.sleep(0.35)

    if not new_products:
        log("没有新商品，结束")
        return

    # 3) 下载商品图
    log("== 下载商品图 %d 张 ..." % len(new_products))
    for p in new_products:
        ext = ext_of(p["image_url"])
        filename = "item_%s%s" % (p["yid"], ext)
        dest = os.path.join(IMG_PRODUCTS, filename)
        try:
            size = download(p["image_url"], dest)
            p["image"] = "/img/products/" + filename
            log("   %-26s %7d B  %s" % (filename, size, p["name"][:26]))
        except Exception as e:
            log("   [warn] 图片失败 %s: %r" % (filename, e))
            p["image"] = ""
        time.sleep(0.12)

    # 4) 轮播图：先把已有横幅统一比例（轮播图已策展过时用 --no-banners 跳过）
    bad_ids = []
    new_banners = []
    need_banners = 0
    if not no_banners:
        log("== 归一已有横幅 ...")
        for f in sorted(os.listdir(IMG_BANNER)):
            path = os.path.join(IMG_BANNER, f)
            im = Image.open(path)
            w, h = im.size
            if w / h < MIN_BANNER_RATIO:
                log("   %-28s %dx%d 比例 %.2f —— 不是横幅，标记待替换" % (f, w, h, w / h))
                continue
            log("   %-28s %dx%d -> %s" % (f, w, h, normalize_banner(path)))

        # 方形图对应的横幅记录：用新抓的宽幅图替换
        bad_rows = mysql("SELECT id, image FROM t_banner ORDER BY id;")
        for row in bad_rows.splitlines():
            bid, img = row.split("\t")
            path = os.path.join(ROOT, "src/main/resources/static", img.lstrip("/"))
            if not os.path.exists(path):
                continue
            w, h = Image.open(path).size
            if w / h < MIN_BANNER_RATIO:
                bad_ids.append((int(bid), img, path))

        # 5) 下载新横幅
        log("== 下载新横幅（仅接受宽高比 >= %.1f 的图）..." % MIN_BANNER_RATIO)
        used_names = set(os.listdir(IMG_BANNER))
        need_banners = len(bad_ids) + NEW_BANNERS
        for url in banner_urls:
            if len(new_banners) >= need_banners:
                break
            ext = ext_of(url)
            filename = "banner_%s%s" % (hashlib.md5(url.encode()).hexdigest()[:8], ext)
            if filename in used_names:
                continue
            tmp = os.path.join(IMG_BANNER, filename)
            try:
                download(url, tmp)
            except Exception as e:
                log("   [warn] 横幅下载失败: %r" % e)
                continue
            w, h = Image.open(tmp).size
            if w / h < MIN_BANNER_RATIO:
                os.remove(tmp)
                log("   [skip] %dx%d 比例 %.2f 不是横幅，已丢弃" % (w, h, w / h))
                continue
            how = normalize_banner(tmp)
            new_banners.append(filename)
            used_names.add(filename)
            log("   %-28s %dx%d -> %s" % (filename, w, h, how))
            time.sleep(0.2)

        if len(new_banners) < len(bad_ids):
            log("   [warn] 新横幅不足，无法替换全部方形图")
    else:
        log("== 跳过轮播图处理（--no-banners）")

    # 6) 生成 SQL
    log("== 生成 sql ...")
    lines = []
    lines.append("-- =============================================================")
    lines.append("-- HarmonyMall 增量补充数据（%s）" % time.strftime("%Y-%m-%d %H:%M"))
    lines.append("-- 商品数据来源：网易严选公开搜索接口；仅新增，不重建已有数据")
    lines.append("-- =============================================================")
    lines.append("USE harmonymall;")
    lines.append("SET NAMES utf8mb4;")
    lines.append("")

    # 轮播图：替换方形图 + 新增
    b_idx = 0
    for bid, old_img, path in bad_ids:
        if b_idx >= len(new_banners):
            break
        lines.append("UPDATE t_banner SET image = '/img/banner/%s' WHERE id = %d;  -- 替换原方形图 %s"
                     % (new_banners[b_idx], bid, os.path.basename(old_img)))
        b_idx += 1
    rest = new_banners[b_idx:]
    if rest:
        lines.append("")
        lines.append("-- 新增轮播图")
        max_bid = int(mysql("SELECT IFNULL(MAX(id),0) FROM t_banner;"))
        rows = []
        for i, fn in enumerate(rest, start=max_bid + 1):
            rows.append("(%d, '/img/banner/%s', 'category', '%d', %d)" % (i, fn, (i - 1) % 4 + 1, i))
        lines.append("INSERT INTO t_banner (id, image, link_type, link_value, sort) VALUES")
        lines.append(",\n".join(rows) + ";")
    lines.append("")

    # 商品 + SKU
    pid = max_pid
    sku_id = max_sku
    product_rows = []
    sku_rows = []
    for p in new_products:
        skus = []
        for s in p["skus"]:
            price = s.get("retailPrice")
            if not price or price <= 0:
                continue
            skus.append({
                "specs": sku_specs(s) or {"规格": "官方标配"},
                "price_fen": int(round(float(price) * 100)),
                "sales": int(s.get("sellVolume") or 0),
            })
        if not skus:
            skus = [{"specs": {"规格": "官方标配"},
                     "price_fen": int(round(p["price_yuan"] * 100)), "sales": 300}]
        min_price = min(s["price_fen"] for s in skus)
        counters = [int(round(float(s.get("counterPrice") or 0) * 100)) for s in p["skus"] if s.get("counterPrice")]
        max_counter = max(counters or [int(round(p["counter_yuan"] * 100))])
        original = max_counter if max_counter > min_price else int(min_price * 1.2)
        sales = sum(s["sales"] for s in skus) or 600

        pid += 1
        desc_html = "<h2>%s</h2><p>%s</p>" % (
            html.escape(p["name"]), html.escape(p["desc"] or "精选好物，品质之选。"))
        if p["image"]:
            desc_html += '<img src="%s"/>' % p["image"]
        product_rows.append("(%d, %d, '%s', '%s', '%s', %d, %d, %d, '%s', 1, 0)" % (
            pid, p["category_id"], esc(p["name"]), esc((p["desc"] or "")[:120]),
            p["image"], min_price, original, sales, esc(desc_html)))
        for s in skus:
            sku_id += 1
            stock = 60 + (sku_id * 41) % 260
            sku_rows.append("(%d, %d, '%s', %d, %d, '%s', 0)" % (
                sku_id, pid, esc(json.dumps(s["specs"], ensure_ascii=False)),
                s["price_fen"], stock, p["image"]))

    lines.append("-- 新增商品 SPU（%d 个）" % len(product_rows))
    lines.append("INSERT INTO t_product (id, category_id, name, subtitle, main_image, price, original_price, sales, detail, status, deleted) VALUES")
    lines.append(",\n".join(product_rows) + ";")
    lines.append("")
    lines.append("-- 新增商品 SKU（%d 个）" % len(sku_rows))
    lines.append("INSERT INTO t_product_sku (id, product_id, specs, price, stock, image, deleted) VALUES")
    lines.append(",\n".join(sku_rows) + ";")
    lines.append("")

    with open(SQL_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    # 7) 导入
    log("== 导入数据库 ...")
    with open(SQL_OUT, encoding="utf-8") as f:
        res = subprocess.run(
            [MYSQL, "-uroot", "-p123456", "--default-character-set=utf8mb4"],
            stdin=f, capture_output=True, text=True, encoding="utf-8")
    if res.returncode != 0:
        log("   [error] 导入失败：" + (res.stderr or "")[:300])
    else:
        log("   导入完成")

    log("== 完成：新增商品 %d 个，新横幅 %d 张，替换方形横幅 %d 张" %
        (len(product_rows), len(rest), min(len(bad_ids), len(new_banners))))
    log("SQL -> " + SQL_OUT)
    for p in new_products:
        log("   [%2d] %-38s ¥%-8.2f" % (p["category_id"], p["name"][:38], p["price_yuan"]))


if __name__ == "__main__":
    main()
