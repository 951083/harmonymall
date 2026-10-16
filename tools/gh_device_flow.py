# -*- coding: utf-8 -*-
"""GitHub Device Flow 授权（容错版）。

背景：本机网络对 github.com 呈分钟级波动（有效请求成功率 ~20%，连接常被重置），
官方 gh CLI 的 device flow 遇到任何一次请求失败就会整体中断，无法完成。
本脚本自行实现 device flow（对 github.com 的端点做无限重试，经本地隧道抓取网络窗口）：

  阶段一：获取设备码（重试直到成功），打印 USER_CODE
  阶段二：轮询领取 token（每 5 秒一次，失败自动重试，直到用户在浏览器完成授权）
  成功后将 token 写入 /tmp/ghtoken.txt

依赖：先用 tools/github_tunnel.py 起好本地隧道（127.0.0.1:8443）。
"""
import json
import time
import urllib.parse
import urllib.request

CLIENT_ID = "178c6fc778ccc68e1d6a"  # GitHub CLI 官方 OAuth App（公开 client id）
SCOPE = "repo"
PROXY = "http://127.0.0.1:8443"
TOKEN_FILE = "/tmp/ghtoken.txt"

OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}))


def post(url, data, timeout=40):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, method="POST", headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json",
        "User-Agent": "harmonymall-deploy",
    })
    with OPENER.open(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def request_code():
    while True:
        try:
            return post("https://github.com/login/device/code",
                        {"client_id": CLIENT_ID, "scope": SCOPE})
        except Exception as e:
            print(f"[retry] device/code 请求失败（等网络窗口）：{e}", flush=True)
            time.sleep(3)


def poll_token(device_code, interval, deadline):
    while time.time() < deadline:
        try:
            d = post("https://github.com/login/oauth/access_token", {
                "client_id": CLIENT_ID,
                "device_code": device_code,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            })
        except Exception as e:
            print(f"[retry] 轮询请求失败（等网络窗口）：{e}", flush=True)
            time.sleep(5)
            continue
        if "access_token" in d:
            return d["access_token"]
        err = d.get("error")
        if err == "authorization_pending":
            time.sleep(interval)
            continue
        if err == "slow_down":
            interval += 5
            time.sleep(interval)
            continue
        print(f"[error] {err}: {d.get('error_description')}", flush=True)
        return None
    return None


def main():
    info = request_code()
    user_code = info["user_code"]
    device_code = info["device_code"]
    interval = int(info.get("interval", 5))
    expires = int(info.get("expires_in", 900))
    print("=" * 46, flush=True)
    print(f"USER_CODE={user_code}", flush=True)
    print(f"URL={info.get('verification_uri', 'https://github.com/login/device')}", flush=True)
    print(f"EXPIRE_IN={expires}s", flush=True)
    print("=" * 46, flush=True)
    token = poll_token(device_code, interval, time.time() + expires - 30)
    if token:
        with open(TOKEN_FILE, "w", encoding="utf-8") as f:
            f.write(token.strip())
        print("AUTH_OK token -> /tmp/ghtoken.txt", flush=True)
    else:
        print("AUTH_FAILED（过期或拒绝）", flush=True)


if __name__ == "__main__":
    main()
