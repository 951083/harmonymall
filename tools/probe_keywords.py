# -*- coding: utf-8 -*-
"""探测补充关键词的可用性（补全文创/家居分类）"""
import json
import ssl
import time
import urllib.parse
import urllib.request

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")

KEYWORDS = ["加湿器", "钢笔", "笔记本", "签字笔", "手账本", "文具盒", "香薰机",
            "四件套", "床品", "收纳盒", "玩偶", "双肩包", "保温杯", "毛巾", "拖鞋"]


def count(keyword):
    url = ("https://you.163.com/xhr/search/search.json?keyword="
           + urllib.parse.quote(keyword)
           + "&page=1&sortType=0&descSorted=false&categoryId=0&matchType=0")
    req = urllib.request.Request(url, headers={
        "User-Agent": UA, "Accept": "application/json", "Referer": "https://you.163.com/"})
    with urllib.request.urlopen(req, timeout=20, context=ctx) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    directly = (data or {}).get("data", {}).get("directly", {})
    result = directly.get("searcherResult", {}) or {}
    items = result.get("result", []) or []
    valid = [i for i in items
             if not i.get("soldOut") and not i.get("underShelf")
             and (i.get("retailPrice") or 0) > 0 and i.get("name")]
    sample = clean(items[0].get("name")) if valid else "-"
    return len(items), len(valid), sample


def clean(name):
    import re
    name = re.sub(r"^【[^】]*】", "", name or "").strip()
    return re.sub(r"\s+", " ", name)[:40]


for kw in KEYWORDS:
    try:
        total, valid, sample = count(kw)
        print("%-8s total=%-3d valid=%-3d %s" % (kw, total, valid, sample))
    except Exception as e:
        print("%-8s ERROR %r" % (kw, e))
    time.sleep(0.3)
