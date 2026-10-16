# -*- coding: utf-8 -*-
"""打印当前页面所有输入类节点（类型 / 占位符 / 坐标），用于自动化点击前定位"""
import json
import os
import sys

p = os.path.join(os.environ["TEMP"], "hm_layout.json")
with open(p, encoding="utf-8") as f:
    d = json.load(f)

nodes = []


def walk(n):
    nodes.append(n)
    for c in n.get("children", []) or []:
        walk(c)


walk(d)

kw = sys.argv[1] if len(sys.argv) > 1 else "Input"
for n in nodes:
    a = n.get("attributes", {})
    t = a.get("type") or ""
    if kw in t:
        print(t, "| placeholder=", a.get("placeholder"), "| text=", repr(a.get("text")), "| bounds=", a.get("bounds"))
