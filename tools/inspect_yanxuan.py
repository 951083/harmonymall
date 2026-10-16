# -*- coding: utf-8 -*-
"""分析网易严选搜索 API 的 JSON 结构"""
import json
import ssl
import urllib.request

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")


def get(url):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept": "application/json",
        "Referer": "https://you.163.com/",
    })
    with urllib.request.urlopen(req, timeout=20, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8"))


def find_item_lists(obj, path="", depth=0, hits=None):
    if hits is None:
        hits = []
    if depth > 6:
        return hits
    if isinstance(obj, dict):
        keys = set(obj.keys())
        if ("itemId" in keys or "id" in keys) and ("title" in keys or "name" in keys):
            hits.append((path, obj))
        for k, v in obj.items():
            find_item_lists(v, path + "/" + str(k), depth + 1, hits)
    elif isinstance(obj, list):
        for i, v in enumerate(obj[:2]):
            find_item_lists(v, path + "[]", depth + 1, hits)
    return hits


data = get("https://you.163.com/xhr/search/search.json?keyword=%E8%80%B3%E6%9C%BA"
           "&page=1&sortType=0&descSorted=false&categoryId=0&matchType=0")

print("== top keys:", list(data.keys()))
d = data.get("data", {})
print("== data keys:", list(d.keys()) if isinstance(d, dict) else type(d))

hits = find_item_lists(data)
print("== candidate item lists:", len(hits))
for path, item in hits[:3]:
    print("--- path:", path)
    print(json.dumps(item, ensure_ascii=False, indent=1)[:1500])
