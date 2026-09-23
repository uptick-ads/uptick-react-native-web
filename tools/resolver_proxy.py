#!/usr/bin/env python3
"""Tiny HTTP CONNECT proxy for the Android emulator.

The emulator forwards guest DNS to the host's system nameservers, which never see puma-dev's `.test` resolver.
Pointing the emulator at this proxy makes the host resolve names instead, so local development hostnames reach the server on 127.0.0.1.
Run: python3 tools/resolver_proxy.py 8899, then: adb shell settings put global http_proxy 10.0.2.2:8899
"""
import select
import socket
import sys
import threading

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8899


def pipe(a, b):
    sockets = [a, b]
    while True:
        readable, _, _ = select.select(sockets, [], [], 60)
        if not readable:
            return
        for s in readable:
            data = s.recv(65536)
            if not data:
                return
            (b if s is a else a).sendall(data)


# Inside the emulator 10.0.2.2 is the host machine, but on the host that address means nothing, so map it back to loopback (Metro on 8081 lives there).
GUEST_HOST_ALIAS = {"10.0.2.2": "127.0.0.1"}


def upstream_host(host):
    return GUEST_HOST_ALIAS.get(host, host)


def handle(client):
    try:
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = client.recv(4096)
            if not chunk:
                return
            head += chunk
        request_line = head.split(b"\r\n", 1)[0].decode(errors="replace")
        method, target, _ = request_line.split(" ", 2)
        if method == "CONNECT":
            host, _, port = target.rpartition(":")
            upstream = socket.create_connection((upstream_host(host), int(port)), timeout=15)
            client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            print(f"CONNECT {host}:{port} -> {upstream.getpeername()[0]}", flush=True)
            pipe(client, upstream)
            return
        # Plain HTTP (Metro, the Expo manifest): forward the absolute-URI request and pipe the rest of the connection.
        if not target.startswith("http://"):
            client.sendall(b"HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n")
            return
        hostport, _, path = target[len("http://"):].partition("/")
        host, _, port = hostport.partition(":")
        upstream = socket.create_connection((upstream_host(host), int(port or 80)), timeout=15)
        head_lines = head.split(b"\r\n")
        head_lines[0] = f"{method} /{path} HTTP/1.1".encode()
        head_lines = [line for line in head_lines if not line.lower().startswith(b"proxy-connection:")]
        upstream.sendall(b"\r\n".join(head_lines))
        print(f"{method} {host}:{port or 80}/{path[:60]} -> {upstream.getpeername()[0]}", flush=True)
        pipe(client, upstream)
    except Exception as e:  # noqa: BLE001 - a dev-only tool, so just log it
        print(f"error: {e}", flush=True)
    finally:
        client.close()


def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", PORT))
    server.listen(64)
    print(f"resolver proxy listening on 0.0.0.0:{PORT}", flush=True)
    while True:
        client, _ = server.accept()
        threading.Thread(target=handle, args=(client,), daemon=True).start()


if __name__ == "__main__":
    main()
