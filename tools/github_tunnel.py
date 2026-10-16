# -*- coding: utf-8 -*-
"""GitHub 本地隧道 v2：把 github.com 的 HTTPS 流量转发到可达 IP，并自动等待网络窗口。

背景（2026-10 实测）：本机网络对 github.com 的访问呈**分钟级波动**——
同一批 IP 会「全部可达（窗口期，延迟 0.5~2s）」与「全部超时」之间周期性切换。
单一固定 IP 的成功率有限，因此本隧道：

1. 维护一个 IP 池，逐个尝试（含「上次成功 IP 优先」缓存）；
2. 全部失败时**不立即断开客户端**，而是循环等待（默认最长 300 秒），
   网络窗口一旦打开立即完成连接——gh / git 的长等待请求因此可以在窗口内完成。

用法：
    # git（会话级，配在需要用的仓库里或临时全局）
    git config http.https://github.com.proxy http://127.0.0.1:8443
    # gh（会话级）
    set HTTPS_PROXY=http://127.0.0.1:8443
"""
import socket
import threading
import time

# github.com 常见边缘 IP（按历史稳定度排序）
UPSTREAM_IPS = [
    "140.82.121.3",
    "140.82.113.3",
    "140.82.114.3",
    "140.82.112.3",
    "20.27.177.113",
    "20.205.243.166",
]
UPSTREAM_PORT = 443
LISTEN = ("127.0.0.1", 8443)

CONNECT_TIMEOUT = 4     # 单个 IP 建连超时（秒）
WAIT_BUDGET = 300       # 等待网络窗口的最长时间（秒）

_last_ok = [None]
_lock = threading.Lock()


def log(msg):
    print(f"[github_tunnel] {msg}", flush=True)


def connect_upstream(deadline):
    """尝试 IP 池建立上游连接；全失败则循环等待窗口，直到 deadline。"""
    tried_round = 0
    while True:
        tried_round += 1
        ips = list(UPSTREAM_IPS)
        with _lock:
            if _last_ok[0] and _last_ok[0] in ips:
                ips.remove(_last_ok[0])
                ips.insert(0, _last_ok[0])
        for ip in ips:
            try:
                s = socket.create_connection((ip, UPSTREAM_PORT), timeout=CONNECT_TIMEOUT)
                s.settimeout(None)
                with _lock:
                    _last_ok[0] = ip
                log(f"upstream OK via {ip} (round {tried_round})")
                return s
            except Exception:
                continue
        if time.time() > deadline:
            log("wait budget exhausted, giving up this connection")
            return None
        time.sleep(2)  # 歇 2 秒，下一轮探测（等网络窗口）


def pipe(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        for s in (src, dst):
            try:
                s.close()
            except Exception:
                pass


def handle(client):
    upstream = None
    try:
        req = b""
        while b"\r\n\r\n" not in req:
            chunk = client.recv(4096)
            if not chunk:
                client.close()
                return
            req += chunk
        first = req.split(b"\r\n", 1)[0].decode("latin1", errors="ignore")
        if not first.upper().startswith("CONNECT"):
            client.sendall(b"HTTP/1.1 405 Method Not Allowed\r\n\r\n")
            client.close()
            return
        deadline = time.time() + WAIT_BUDGET
        upstream = connect_upstream(deadline)
        if upstream is None:
            client.sendall(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
            client.close()
            return
        client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        threading.Thread(target=pipe, args=(client, upstream), daemon=True).start()
        threading.Thread(target=pipe, args=(upstream, client), daemon=True).start()
    except Exception:
        for s in (client, upstream):
            if s:
                try:
                    s.close()
                except Exception:
                    pass


def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(LISTEN)
    server.listen(64)
    log(f"v2 listen {LISTEN[0]}:{LISTEN[1]} -> pool {len(UPSTREAM_IPS)} ips, wait budget {WAIT_BUDGET}s")
    while True:
        conn, _ = server.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
