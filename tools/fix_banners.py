# -*- coding: utf-8 -*-
"""HarmonyMall 轮播图策展脚本

轮播图是首页视觉的第一屏，除了"比例正确"，主题还要能对上商城的分类，
否则点"个人护理"跳到"服饰"会显得数据是凑的。本脚本：
  1. 从网易严选分类横幅里挑主题匹配 4 个一级分类的宽幅图
  2. 只接受宽高比 >= 2.2 的图（商品主图是 1:1，混进来会被裁成一条 —— 之前就是这么出问题的）
  3. 统一归一到 2.8:1（与服务端 App 展示比例一致）
  4. 重建 t_banner，并清理不再引用的图片文件
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image
from add_products import (IMG_BANNER, ROOT, download, ext_of, mysql, normalize_banner, log)

# 已在库、主题匹配的横幅：(文件名, 主题, 关联分类 ID)
KEEP = [
    ("banner_496c9397.jpg", "数码家电", 1),
    ("banner_49910019.jpg", "家具家装", 3),
    ("banner_db25644d.jpg", "日用百货", 3),
    ("banner_b5f3e100.jpg", "餐厨好物", 12),
]

# 待补充的横幅：(严选横幅 URL, 主题, 关联分类 ID)
# 分类 ID：1 数码 / 2 服饰 / 3 家居 / 4 文创 / 12 厨房用品 / 15 床品
PICKS = [
    ("http://yanxuan.nosdn.127.net/17b4feb79e45c0e0b52b7a52725cc7b8.jpg", "女装", 2),
    ("http://yanxuan.nosdn.127.net/3768fa50dd5ca3aa0537a72990b48554.jpg", "男装", 2),
    ("http://yanxuan.nosdn.127.net/c3d0dbc79e22b1f3d9757f6153690d73.jpg", "床品家纺", 15),
    ("http://yanxuan.nosdn.127.net/f326744b5624d08a68ff181366739f09.png", "原创设计", 4),
]


def main():
    import hashlib
    rows = []
    keep_files = set()

    log("== 检查已有横幅 ...")
    for filename, theme, cid in KEEP:
        path = os.path.join(IMG_BANNER, filename)
        if not os.path.exists(path):
            log("   [skip] 缺少 %s" % filename)
            continue
        w, h = Image.open(path).size
        if w / h < 2.2:
            log("   [skip] %s 比例 %.2f 不是横幅" % (filename, w / h))
            continue
        log("   %-28s %-8s -> 分类 %2d" % (filename, theme, cid))
        rows.append((filename, cid))
        keep_files.add(filename)

    log("== 下载补充横幅 ...")
    for url, theme, cid in PICKS:
        filename = "banner_%s%s" % (hashlib.md5(url.encode()).hexdigest()[:8], ext_of(url))
        path = os.path.join(IMG_BANNER, filename)
        if not os.path.exists(path):
            try:
                download(url, path)
            except Exception as e:
                log("   [warn] %s 下载失败: %r" % (theme, e))
                continue
        w, h = Image.open(path).size
        if w / h < 2.2:
            log("   [skip] %s %dx%d 比例 %.2f 不是横幅，丢弃" % (theme, w, h, w / h))
            os.remove(path)
            continue
        how = normalize_banner(path)
        log("   %-28s %-8s -> 分类 %2d  (%dx%d %s)" % (filename, theme, cid, w, h, how))
        rows.append((filename, cid))
        keep_files.add(filename)

    if len(rows) < 4:
        log("可用横幅不足，放弃重建")
        return

    # 重建 t_banner
    log("== 重建 t_banner（%d 条）..." % len(rows))
    sql = ["DELETE FROM t_banner;"]
    values = []
    for i, (filename, cid) in enumerate(rows, start=1):
        values.append("(%d, '/img/banner/%s', 'category', '%d', %d)" % (i, filename, cid, i))
    sql.append("INSERT INTO t_banner (id, image, link_type, link_value, sort) VALUES")
    sql.append(",\n".join(values) + ";")
    mysql("\n".join(sql), plain=False)

    # 清理不再引用的图片
    log("== 清理未引用的横幅图 ...")
    for f in sorted(os.listdir(IMG_BANNER)):
        if f not in keep_files:
            os.remove(os.path.join(IMG_BANNER, f))
            log("   删除 %s" % f)

    log("== 完成，当前轮播图：")
    out = mysql("SELECT b.id, b.image, b.link_value, c.name FROM t_banner b "
                "LEFT JOIN t_category c ON c.id = b.link_value ORDER BY b.sort;")
    for line in out.splitlines():
        log("   " + line.replace("\t", "  "))


if __name__ == "__main__":
    main()
