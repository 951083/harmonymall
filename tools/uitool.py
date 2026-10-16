#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
HarmonyMall 模拟器 UI 测试助手
用法：
  python uitool.py find  <文本> [--idx N]      打印匹配节点的 bounds/center
  python uitool.py tap   <文本> [--idx N]      点击匹配节点
  python uitool.py tapxy <x> <y>               点击坐标
  python uitool.py back                        返回键
  python uitool.py shot  <文件名>              截图并保存到截图目录
  python uitool.py dump  [关键字]              打印布局文本（可选过滤）
  python uitool.py text  <x> <y> <文本>        在坐标处输入文本
"""
import json
import os
import shutil
import subprocess
import sys

HDC = r"D:/devecostudio-windows-6.1.1.290/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
SHOT_DIR = r"C:/Users/95108/WorkBuddy/毕业设计/鸿蒙商城/截图"
LAYOUT_LOCAL = os.path.join(os.environ.get("TEMP", "/tmp"), "hm_layout.json")


def hdc(*args, pathconv=True, cwd=None):
    env = dict(os.environ)
    if not pathconv:
        env["MSYS_NO_PATHCONV"] = "1"
    p = subprocess.run([HDC] + list(args), capture_output=True, env=env, cwd=cwd)
    out = p.stdout.decode("utf-8", "ignore")
    err = p.stderr.decode("utf-8", "ignore")
    return out + err


def dump():
    hdc("shell", "uitest dumpLayout -p /data/local/tmp/layout.json")
    tmpdir = os.environ.get("TEMP", "/tmp")
    if os.path.exists(LAYOUT_LOCAL):
        os.remove(LAYOUT_LOCAL)
    hdc("file", "recv", "/data/local/tmp/layout.json", "hm_layout.json",
        pathconv=False, cwd=tmpdir)
    with open(LAYOUT_LOCAL, "r", encoding="utf-8") as f:
        return json.load(f)


def walk(node, out):
    out.append(node)
    for c in node.get("children", []) or []:
        walk(c, out)


def all_nodes(tree):
    out = []
    walk(tree, out)
    return out


def center(bounds):
    # bounds 形如 "[1119,2643][1204,2692]"
    try:
        left_top, right_bottom = bounds.split("][")
        x1, y1 = [int(v) for v in left_top.strip("[]").split(",")]
        x2, y2 = [int(v) for v in right_bottom.strip("[]").split(",")]
        return (x1 + x2) // 2, (y1 + y2) // 2
    except Exception:
        return None


def matches(text, target, exact=False):
    text = text or ""
    return text == target if exact else target in text


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    cmd = sys.argv[1]

    if cmd == "dump":
        tree = dump()
        kw = sys.argv[2] if len(sys.argv) > 2 else ""
        for n in all_nodes(tree):
            a = n.get("attributes", {})
            t = a.get("text", "")
            if t and (not kw or kw in t):
                print(repr(t), a.get("bounds"))
        return

    if cmd in ("find", "tap"):
        target = sys.argv[2]
        idx = 0
        exact = False
        if "--idx" in sys.argv:
            idx = int(sys.argv[sys.argv.index("--idx") + 1])
        if "--exact" in sys.argv:
            exact = True
        tree = dump()
        hits = []
        for n in all_nodes(tree):
            a = n.get("attributes", {})
            if matches(a.get("text", ""), target, exact):
                c = center(a.get("bounds", ""))
                if c:
                    hits.append((a.get("text"), a.get("bounds"), c))
        if not hits:
            print("NOT FOUND:", target)
            return
        for i, (t, b, c) in enumerate(hits):
            print(i, repr(t), b, "center", c)
        t, b, c = hits[idx]
        if cmd == "tap":
            hdc("shell", "uitest uiInput click %d %d" % c)
            print("TAPPED", repr(t), c)
        return

    if cmd == "tapxy":
        x, y = int(sys.argv[2]), int(sys.argv[3])
        hdc("shell", "uitest uiInput click %d %d" % (x, y))
        print("TAPPED", x, y)
        return

    if cmd == "back":
        hdc("shell", "uitest uiInput keyEvent 2")
        print("BACK")
        return

    if cmd == "text":
        x, y, txt = int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
        hdc("shell", "uitest uiInput inputText %d %d %s" % (x, y, txt))
        print("INPUT", txt)
        return

    if cmd == "shot":
        name = sys.argv[2]
        if not name.lower().endswith(".jpeg"):
            name += ".jpeg"
        hdc("shell", "snapshot_display -f /data/local/tmp/shot.jpeg")
        os.makedirs(SHOT_DIR, exist_ok=True)
        # hdc 的 file recv 只认「相对当前目录」的路径，中文路径也容易出问题：
        # 先切到系统临时目录用英文文件名接收，再拷到截图目录
        tmpdir = os.environ.get("TEMP", "/tmp")
        tmp = os.path.join(tmpdir, "hm_shot.jpeg")
        if os.path.exists(tmp):
            os.remove(tmp)
        out = hdc("file", "recv", "/data/local/tmp/shot.jpeg", "hm_shot.jpeg",
                  pathconv=False, cwd=tmpdir)
        if not os.path.exists(tmp):
            print("RECV FAILED:", out)
            return
        dst = os.path.join(SHOT_DIR, name)
        shutil.copyfile(tmp, dst)
        print("SAVED", dst, os.path.getsize(dst))
        return

    print(__doc__)


if __name__ == "__main__":
    main()
