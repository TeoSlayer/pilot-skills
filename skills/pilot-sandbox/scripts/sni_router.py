#!/usr/bin/env python3
"""Transparent SNI router for Pilot Protocol's TLS endpoints.

Listens on 127.0.0.1:443 (override with PILOT_SNI_LISTEN=host:port). For each
connection it reads the TLS ClientHello, extracts the SNI hostname WITHOUT
modifying a single byte, opens a CONNECT tunnel through the egress HTTPS proxy
to the matching real host, replays the original ClientHello, then pipes both
directions until either side closes.

The TLS handshake stays end-to-end between pilot-daemon and the real server,
so certificate verification and the TLS 1.3 transcript both survive. Rewriting
the SNI in flight does NOT work: TLS binds the session keys to the exact
ClientHello bytes, and the server answers a rewritten hello with
DECRYPTION_FAILED_OR_BAD_RECORD_MAC.

Environment:
  HTTPS_PROXY        required. http(s)://[user:pass@]host[:port] (port defaults
                     to 80 for http, 443 for https; percent-encode reserved
                     characters in the credentials)
  PILOT_SNI_LISTEN   optional. default 127.0.0.1:443

Nothing it prints contains the proxy credentials: every log line goes through
scrub(), and an unusable HTTPS_PROXY is rejected without echoing it.

Pair this with run-daemon.sh, which bind-mounts a hosts file that points the
Pilot hostnames at this listener inside a private mount namespace.
"""
import base64
import os
import re
import socket
import ssl
import sys
import threading
from urllib.parse import unquote, urlsplit

DEFAULT_LISTEN = ("127.0.0.1", 443)

# SNI hostname -> (real target host, port) reached through the proxy CONNECT.
ROUTES = {
    "registry.pilotprotocol.network": ("registry.pilotprotocol.network", 443),
    "beacon.pilotprotocol.network": ("beacon.pilotprotocol.network", 443),
}


def extract_sni(data: bytes):
    """Parse the first TLS record and return the ClientHello SNI, or None."""
    try:
        if len(data) < 5 or data[0] != 0x16:  # handshake record
            return None
        rec_len = int.from_bytes(data[3:5], "big")
        if len(data) < 5 + rec_len or data[5] != 0x01:  # ClientHello
            return None
        hs_len = int.from_bytes(data[6:9], "big")
        body = data[9:9 + hs_len]
        p = 2 + 32                                    # client_version + random
        p += 1 + body[p]                              # session_id
        cs_len = int.from_bytes(body[p:p + 2], "big")
        p += 2 + cs_len                               # cipher_suites
        p += 1 + body[p]                              # compression_methods
        ext_len = int.from_bytes(body[p:p + 2], "big")
        exts = body[p + 2:p + 2 + ext_len]
        q = 0
        while q + 4 <= len(exts):
            etype = int.from_bytes(exts[q:q + 2], "big")
            elen = int.from_bytes(exts[q + 2:q + 4], "big")
            edata = exts[q + 4:q + 4 + elen]
            if etype == 0 and len(edata) >= 5:        # server_name
                # server_name_list: list_len(2) name_type(1)=0 name_len(2) name
                nl = int.from_bytes(edata[3:5], "big")
                return edata[5:5 + nl].decode("ascii", errors="replace")
            q += 4 + elen
    except (IndexError, ValueError):
        pass
    return None


def recv_hello(sock) -> bytes:
    """Read exactly one TLS record (the ClientHello) from the client."""
    sock.settimeout(10)
    data = b""
    while len(data) < 5:
        chunk = sock.recv(5 - len(data))
        if not chunk:
            return data
        data += chunk
    if data[0] != 0x16:
        return data
    rec_len = int.from_bytes(data[3:5], "big")
    while len(data) < 5 + rec_len:
        chunk = sock.recv(5 + rec_len - len(data))
        if not chunk:
            break
        data += chunk
    return data


class Proxy:
    """A parsed egress proxy. Holds the credentials; never print it."""

    def __init__(self, url: str):
        try:
            p = urlsplit(url.strip())
            scheme = (p.scheme or "").lower()
            host = p.hostname
            port = p.port
        except ValueError:
            raise ValueError("HTTPS_PROXY is not a valid proxy URL") from None
        if scheme not in ("http", "https"):
            raise ValueError("HTTPS_PROXY must be an http:// or https:// URL")
        if not host or "@" in (p.path + p.query + p.fragment):
            raise ValueError(
                "HTTPS_PROXY is not a valid proxy URL "
                "(percent-encode '@', '/', '?' and '#' in the credentials)")
        self.scheme = scheme
        self.host = host
        self.port = port or (443 if scheme == "https" else 80)
        self.auth = None
        secrets = set()
        if p.username is not None:
            secrets |= {url, url.strip()}
            user = unquote(p.username)
            password = unquote(p.password or "")
            token = base64.b64encode(f"{user}:{password}".encode()).decode()
            self.auth = f"Basic {token}"
            secrets |= {token, f"{p.username}:{p.password or ''}", f"{user}:{password}"}
            secrets |= {x for x in (p.password or "", password) if len(x) >= 4}
            # A short user name is usually a plain word that would mask
            # hostnames in the log; a long one is treated as a token.
            secrets |= {x for x in (p.username, user) if len(x) >= 8}
        # Longest first, so a secret that contains another is masked whole.
        self.secrets = sorted((x for x in secrets if len(x) >= 2), key=len, reverse=True)

    def __repr__(self):
        return f"Proxy({self.redacted()})"

    def redacted(self) -> str:
        auth = "***@" if self.auth else ""
        return f"{self.scheme}://{auth}{self.host}:{self.port}"


_USERINFO = re.compile(r"([A-Za-z][A-Za-z0-9+.-]*://)[^\s/]*@")


def scrub(text, proxy=None) -> str:
    """Mask credentials in text: any scheme://user:pass@ (up to the last @ of
    the token) and, when a proxy is given, every form of its secrets."""
    out = _USERINFO.sub(r"\1***@", str(text))
    if proxy is not None:
        for secret in proxy.secrets:
            out = out.replace(secret, "***")
    return out


def log(msg, proxy=None):
    print(scrub(msg, proxy), flush=True)


def proxy_connect(proxy: Proxy, target_host: str, target_port: int):
    """Open a CONNECT tunnel through the proxy; return the socket or None."""
    up = socket.create_connection((proxy.host, proxy.port), timeout=15)
    if proxy.scheme == "https":
        up = ssl.create_default_context().wrap_socket(up, server_hostname=proxy.host)
    headers = (
        f"CONNECT {target_host}:{target_port} HTTP/1.1\r\n"
        f"Host: {target_host}:{target_port}\r\n"
    )
    if proxy.auth:
        headers += f"Proxy-Authorization: {proxy.auth}\r\n"
    up.sendall((headers + "\r\n").encode())

    # Read the full response head (until the blank line) before replaying.
    resp = b""
    while b"\r\n\r\n" not in resp:
        chunk = up.recv(4096)
        if not chunk:
            break
        resp += chunk
        if len(resp) > 65536:
            break
    status_line = resp.split(b"\r\n", 1)[0]
    if b" 200" not in status_line:
        log(f"proxy refused CONNECT {target_host}:{target_port}: {status_line!r}", proxy)
        up.close()
        return None
    return up


def pipe(src, dst):
    try:
        while True:
            d = src.recv(65536)
            if not d:
                break
            dst.sendall(d)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def handle(client, proxy):
    up = None
    try:
        hello = recv_hello(client)
        sni = extract_sni(hello)
        route = ROUTES.get(sni)
        if route is None:
            log(f"no route for SNI={sni!r}, closing", proxy)
            return
        target_host, target_port = route
        up = proxy_connect(proxy, target_host, target_port)
        if up is None:
            return
        log(f"routed SNI={sni} -> {target_host}:{target_port}", proxy)
        up.settimeout(None)
        client.settimeout(None)
        up.sendall(hello)  # replay the ORIGINAL bytes, unmodified
        t1 = threading.Thread(target=pipe, args=(client, up), daemon=True)
        t2 = threading.Thread(target=pipe, args=(up, client), daemon=True)
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception as e:  # noqa: BLE001 - log and drop the connection
        log(f"handle error: {e}", proxy)
    finally:
        for s in (client, up):
            try:
                if s is not None:
                    s.close()
            except OSError:
                pass


def parse_listen(value: str):
    host, _, port = value.rpartition(":")
    return (host or "127.0.0.1", int(port))


def main():
    raw = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy")
    if not raw:
        sys.exit("HTTPS_PROXY not set")
    try:
        proxy = Proxy(raw)
    except ValueError as e:  # our own messages: they never contain the URL
        sys.exit(f"sni_router: {e}")
    listen = parse_listen(os.environ.get("PILOT_SNI_LISTEN", "")) if os.environ.get("PILOT_SNI_LISTEN") else DEFAULT_LISTEN
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(listen)
    srv.listen(100)
    log(f"SNI router listening on {listen[0]}:{listen[1]} via proxy {proxy.redacted()}", proxy)
    while True:
        c, _ = srv.accept()
        threading.Thread(target=handle, args=(c, proxy), daemon=True).start()


if __name__ == "__main__":
    main()
