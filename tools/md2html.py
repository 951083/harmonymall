# -*- coding: utf-8 -*-
"""把毕业设计 Markdown 文档转为带样式的 HTML（浅色主题，便于预览/打印）。"""
import sys
from pathlib import Path

import markdown

CSS = """
:root { color-scheme: light; }
* { box-sizing: border-box; }
body {
  margin: 0; padding: 40px 20px 80px;
  background: #f2f4f7;
  font-family: "Microsoft YaHei", "PingFang SC", "Segoe UI", sans-serif;
  color: #1f2328; font-size: 15px; line-height: 1.75;
}
main { max-width: 920px; margin: 0 auto; }
h1 {
  font-size: 26px; margin: 0 0 8px; padding-bottom: 14px;
  border-bottom: 3px solid #2563eb; letter-spacing: .5px;
}
h2 {
  font-size: 20px; margin: 42px 0 14px; padding-left: 10px;
  border-left: 5px solid #2563eb; background: #eaf0fb;
  padding-top: 4px; padding-bottom: 4px; border-radius: 0 6px 6px 0;
}
h3 { font-size: 17px; margin: 26px 0 10px; color: #1d4ed8; }
p { margin: 10px 0; }
blockquote {
  margin: 14px 0; padding: 10px 16px; background: #fff8e6;
  border-left: 4px solid #f0b429; border-radius: 0 6px 6px 0; color: #6b5b1e;
}
table {
  border-collapse: collapse; width: 100%; margin: 14px 0 22px;
  background: #fff; font-size: 14px;
  box-shadow: 0 1px 3px rgba(16,24,40,.08); border-radius: 8px; overflow: hidden;
}
th {
  background: #2563eb; color: #fff; font-weight: 600; text-align: left;
  padding: 9px 12px; white-space: nowrap;
}
td { padding: 8px 12px; border-bottom: 1px solid #e5e9f0; vertical-align: top; }
tr:nth-child(even) td { background: #f8fafc; }
tr:last-child td { border-bottom: none; }
code {
  background: #eef1f5; border: 1px solid #dde3ea; border-radius: 4px;
  padding: 1px 6px; font-size: 13px;
  font-family: Consolas, "Courier New", monospace; color: #b42318;
}
pre { background: #262c36; color: #e6edf3; padding: 14px 16px; border-radius: 8px; overflow-x: auto; }
pre code { background: none; border: none; color: inherit; padding: 0; }
ul, ol { padding-left: 26px; }
li { margin: 4px 0; }
strong { color: #111827; }
hr { border: none; border-top: 1px dashed #cbd5e1; margin: 34px 0; }
a { color: #2563eb; }
"""


def main() -> None:
    src = Path(sys.argv[1]).resolve()
    dst = Path(sys.argv[2]).resolve()
    text = src.read_text(encoding="utf-8")
    body = markdown.markdown(text, extensions=["tables", "fenced_code", "sane_lists"])
    title = src.stem
    html = (
        "<!DOCTYPE html>\n<html lang=\"zh-CN\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        f"<title>{title}</title>\n<style>{CSS}</style>\n</head>\n<body>\n<main>\n{body}\n</main>\n</body>\n</html>"
    )
    dst.write_text(html, encoding="utf-8")
    print(f"OK -> {dst} ({len(html)} chars)")


if __name__ == "__main__":
    main()
