# -*- coding: utf-8 -*-
"""探测可爬取的购物网站数据源"""
import ssl
import urllib.request
import urllib.error

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")

TARGETS = [
    ("yanxuan", "https://you.163.com/xhr/search/search.json?keyword=%E8%80%B3%E6%9C%BA&page=1&sortType=0&descSorted=false&categoryId=0&matchType=0"),
    ("dangdang", "https://search.dangdang.com/?key1=%E8%80%B3%E6%9C%BA&act=input"),
    ("suning", "https://search.suning.com/%E8%80%B3%E6%9C%BA/"),
    ("jd_pc", "https://search.jd.com/Search?keyword=%E8%80%B3%E6%9C%BA&enc=utf-8"),
    ("jd_m", "https://so.m.jd.com/ware/search.action?keyword=%E8%80%B3%E6%9C%BA"),
    ("smzdm", "https://search.smzdm.com/?c=home&s=%E8%80%B3%E6%9C%BA&v=b"),
    ("miaosha", "https://api.m.jd.com/client.action?functionId=newStudioGoodsSearch"),
]

for name, url in TARGETS:
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": UA,
            "Accept": "text/html,application/json,application/xhtml+xml,*/*",
            "Accept-Language": "zh-CN,zh;q=0.9",
        })
        with urllib.request.urlopen(req, timeout=15, context=ctx) as resp:
            body = resp.read()
            ctype = resp.headers.get("Content-Type", "")
            print(name, "->", resp.status, len(body), "bytes,", ctype)
            snippet = body[:160].decode("utf-8", "ignore").replace("\n", " ")
            print("   head:", snippet)
    except urllib.error.HTTPError as e:
        print(name, "-> HTTP", e.code, e.reason)
    except Exception as e:
        print(name, "-> ERROR", repr(e)[:160])
