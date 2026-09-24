#!/usr/bin/env python3
"""Credential-refreshing egress relay. Listens on 127.0.0.1:3128.

For every request: strips the client's Proxy-Authorization, stamps fresh
credentials read from a fresh shell (the sandbox rotates them; long-lived
processes otherwise start getting 407s), forwards to the real egress proxy,
and retries once with re-read credentials on a 407.

Never terminates TLS. Never logs credential values.

pilot-up.sh starts it (pid in ~/.pilot/egress_relay.pid) when the installed
pilot-daemon cannot re-read rotated credentials itself (no -proxy-cmd), and
points the SNI router and the daemon at it. By hand:

  nohup python3 egress_relay.py > /dev/null 2>&1 &

Environment (all optional):
  RELAY_CRED_CMD  shell command printing the current proxy URL, run with
                  bash -c (default: printf %s "${https_proxy:-$HTTPS_PROXY}")
  RELAY_LISTEN    host:port to listen on (default 127.0.0.1:3128)
  RELAY_LOG       log file (default /tmp/egress_relay.log), created 0600
"""
import base64, os, socket, subprocess, threading, time, urllib.parse


def parse_listen(value):
    host, _, port = value.rpartition(":")
    return (host or "127.0.0.1", int(port))


LISTEN = parse_listen(os.environ.get("RELAY_LISTEN") or "127.0.0.1:3128")
# How to read the *current* proxy URL. A fresh shell picks up rotated creds.
CRED_CMD = os.environ.get("RELAY_CRED_CMD",
                          'printf %s "${https_proxy:-$HTTPS_PROXY}"')
CACHE_SECONDS = 60
LOG = open(os.open(os.environ.get("RELAY_LOG") or "/tmp/egress_relay.log",
                   os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600),
           "a", buffering=1)
LOOPBACK = {"127.0.0.1", "localhost", "::1", LISTEN[0]}

_lock = threading.Lock()
_cache = {"auth": None, "upstream": None, "at": 0.0}


def log(msg):
    LOG.write(f"[{time.strftime('%H:%M:%S')}] {msg}\n")


def current_proxy(force=False):
    """Return (upstream (host, port), basic-auth token or None), cached."""
    with _lock:
        if not force and _cache["upstream"] and time.time() - _cache["at"] < CACHE_SECONDS:
            return _cache["upstream"], _cache["auth"]
        try:
            url = subprocess.run(["bash", "-c", CRED_CMD], capture_output=True,
                                 stdin=subprocess.DEVNULL,
                                 timeout=10).stdout.decode().strip()
            pu = urllib.parse.urlsplit(url if "://" in url else "http://" + url)
            auth = None
            if pu.username is not None:
                # userinfo is percent-encoded in the URL; the header wants it raw.
                user = urllib.parse.unquote(pu.username)
                pw = urllib.parse.unquote(pu.password or "")
                auth = base64.b64encode(f"{user}:{pw}".encode()).decode()
            upstream = (pu.hostname, pu.port or 3128) if pu.hostname else None
            if upstream and upstream[0] in LOOPBACK and upstream[1] == LISTEN[1]:
                # The shell's proxy is this relay (its URL was exported where
                # the relay started): forwarding there would loop forever.
                log("cred-refresh failed: the proxy URL points at this relay; "
                    "start it from a shell whose HTTPS_PROXY is the real proxy")
            elif upstream:
                _cache.update(upstream=upstream, auth=auth, at=time.time())
            else:
                log("cred-refresh failed: no proxy URL from the credential command")
        except Exception as e:
            log(f"cred-refresh failed: {type(e).__name__}")
        return _cache["upstream"], _cache["auth"]


def read_head(sock, limit=65536):
    """Read up to the end of the HTTP header block. Returns (head, rest)."""
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk or len(buf) > limit:
            return None, None
        buf += chunk
    head, _, rest = buf.partition(b"\r\n\r\n")
    return head.decode("latin-1"), rest


def pipe(src, dst):
    """Copy src -> dst until EOF, then half-close dst so the other
    direction can finish (TLS close_notify and late replies survive)."""
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def handle(client):
    up = None
    try:
        head, rest = read_head(client)
        if head is None:
            return
        lines = [ln for ln in head.split("\r\n")
                 if not ln.lower().startswith("proxy-authorization:")]
        log(" ".join(lines[0].split(" ", 2)[:2]))  # method + target only
        for attempt in (1, 2):
            upstream, auth = current_proxy(force=(attempt == 2))
            if not upstream:
                client.sendall(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
                return
            hdrs = lines + ([f"Proxy-Authorization: Basic {auth}"] if auth else [])
            up = socket.create_connection(upstream, timeout=20)
            up.sendall(("\r\n".join(hdrs) + "\r\n\r\n").encode("latin-1") + rest)
            resp_head, resp_rest = read_head(up)
            status = (resp_head or "").split("\r\n", 1)[0]
            log(f"upstream -> {status[:60]!r}")
            if status.split(" ")[1:2] == ["407"]:
                if attempt == 1:
                    up.close()
                    continue  # creds rotated under us: re-read them and retry once
                log("rejected after re-reading the credentials: the proxy URL "
                    "the credential command prints does not work")
            break
        if resp_head is None:
            client.sendall(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
            return
        client.sendall((resp_head + "\r\n\r\n").encode("latin-1") + resp_rest)
        # The 20 s timeout was for the handshake only. Tunnels (registry TLS,
        # beacon WebSocket) sit idle far longer than that.
        up.settimeout(None)
        client.settimeout(None)
        t = threading.Thread(target=pipe, args=(up, client), daemon=True)
        t.start()
        pipe(client, up)
        t.join()
    except Exception as e:
        log(f"ERR {type(e).__name__}")
    finally:
        for s in (client, up):
            if s is not None:
                try:
                    s.close()
                except OSError:
                    pass


def main():
    current_proxy()
    family = socket.AF_INET6 if ":" in LISTEN[0] else socket.AF_INET
    srv = socket.socket(family, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(LISTEN)
    srv.listen(128)
    log(f"listening on {LISTEN[0]}:{LISTEN[1]}")
    while True:
        try:
            c, _ = srv.accept()
        except OSError as e:
            # Out of file descriptors, or a connection reset before accept:
            # keep serving instead of dying under the daemon.
            log(f"accept failed: {type(e).__name__}")
            time.sleep(0.1)
            continue
        threading.Thread(target=handle, args=(c,), daemon=True).start()


if __name__ == "__main__":
    main()
