#!/usr/bin/env python3
"""Tests for skills/pilot-sandbox/scripts/egress_relay.py against a fake
authenticating proxy whose password rotates, like Meta Muse's egress proxy.

The relay runs as a subprocess on a free loopback port. Its credential
command reads a file standing in for "a fresh shell's $https_proxy". No
network beyond 127.0.0.1.

Usage:  python3 tests/test_egress_relay.py [-v]
"""

import base64
import os
import pathlib
import socket
import stat
import subprocess
import sys
import tempfile
import threading
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
RELAY = ROOT / "skills" / "pilot-sandbox" / "scripts" / "egress_relay.py"


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def read_head(sock):
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            break
        buf += chunk
    head, _, rest = buf.partition(b"\r\n\r\n")
    return head.decode("latin-1"), rest


class FakeProxy:
    """Accepts CONNECT only with Basic user:password (password settable, as a
    rotation does), then echoes the tunnel's bytes. Records every
    Proxy-Authorization header it was sent."""

    def __init__(self, user, password):
        self.user = user
        self.password = password
        self.seen = []
        self.srv = socket.socket()
        self.srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.srv.bind(("127.0.0.1", 0))
        self.srv.listen(16)
        self.port = self.srv.getsockname()[1]
        threading.Thread(target=self.serve, daemon=True).start()

    def token(self):
        return base64.b64encode(f"{self.user}:{self.password}".encode()).decode()

    def serve(self):
        while True:
            try:
                c, _ = self.srv.accept()
            except OSError:
                return
            threading.Thread(target=self.handle, args=(c,), daemon=True).start()

    def handle(self, c):
        with c:
            head, rest = read_head(c)
            auths = [ln.split(":", 1)[1].strip() for ln in head.split("\r\n")
                     if ln.lower().startswith("proxy-authorization:")]
            self.seen.append(auths)
            if auths != [f"Basic {self.token()}"]:
                c.sendall(b"HTTP/1.1 407 Proxy Authentication Required\r\n"
                          b"Proxy-Authenticate: Basic realm=\"x\"\r\n\r\n")
                return
            c.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n" + rest)
            while True:
                data = c.recv(65536)
                if not data:
                    return
                c.sendall(data)

    def close(self):
        self.srv.close()


class RelayTest(unittest.TestCase):
    # Extra environment for the relay (RelayTokenTest sets RELAY_TOKEN_FILE).
    relay_env = {}

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        d = self.dir = pathlib.Path(self.tmp.name)
        self.cred_file = d / "current-proxy"
        self.log = d / "relay.log"
        self.proxy = FakeProxy("muse", "pw-1")
        self.set_proxy_url(f"http://muse:pw-1@127.0.0.1:{self.proxy.port}")
        self.port = free_port()
        self.relay = self.start_relay(**{k: v.format(dir=d) for k, v in self.relay_env.items()})
        deadline = time.time() + 10
        while time.time() < deadline:
            try:
                socket.create_connection(("127.0.0.1", self.port), timeout=1).close()
                break
            except OSError:
                time.sleep(0.05)
        else:
            self.fail("relay did not start listening")

    def start_relay(self, **extra):
        env = dict(os.environ,
                   RELAY_LISTEN=f"127.0.0.1:{self.port}",
                   RELAY_LOG=str(self.log),
                   RELAY_CRED_CMD=f"cat {self.cred_file}")
        env.pop("RELAY_TOKEN_FILE", None)
        env.update(extra)
        return subprocess.Popen([sys.executable, str(RELAY)], env=env,
                                stdin=subprocess.DEVNULL,
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.PIPE)

    def tearDown(self):
        self.relay.terminate()
        self.relay.communicate(timeout=10)
        self.proxy.close()
        self.tmp.cleanup()

    def set_proxy_url(self, url):
        self.cred_file.write_text(url + "\n")

    def connect(self, extra=b""):
        """CONNECT through the relay; returns (status line, socket)."""
        s = socket.create_connection(("127.0.0.1", self.port), timeout=10)
        s.sendall(b"CONNECT registry.pilotprotocol.network:443 HTTP/1.1\r\n"
                  b"Host: registry.pilotprotocol.network:443\r\n" + extra + b"\r\n")
        head, _ = read_head(s)
        return head.split("\r\n", 1)[0], s

    def log_text(self):
        return self.log.read_text() if self.log.exists() else ""

    def test_stamps_fresh_credentials_and_strips_the_clients(self):
        status, s = self.connect(b"Proxy-Authorization: Basic c3RhbGU6c3RhbGU=\r\n")
        with s:
            self.assertIn(" 200 ", status)
            s.sendall(b"ping")
            self.assertEqual(s.recv(4), b"ping")
        self.assertEqual(self.proxy.seen[-1], [f"Basic {self.proxy.token()}"])

    def test_rotation_mid_cache_retries_once_with_reread_credentials(self):
        status, s = self.connect()  # caches pw-1 for 60 s
        s.close()
        self.assertIn(" 200 ", status)
        # The sandbox rotates: the proxy now wants pw-2, a fresh shell sees it.
        self.proxy.password = "pw-2"
        self.set_proxy_url(f"http://muse:pw-2@127.0.0.1:{self.proxy.port}")
        status, s = self.connect()
        s.close()
        self.assertIn(" 200 ", status)
        self.assertEqual(len(self.proxy.seen), 3)  # 200, then 407 + retried 200
        log = self.log_text()
        self.assertIn("407", log)
        self.assertLess(log.rindex("407"), log.rindex("200"))

    def test_rejected_even_after_reread_is_passed_back(self):
        self.proxy.password = "never-issued"
        status, s = self.connect()
        s.close()
        self.assertIn(" 407 ", status)
        # pilot-up.sh restarts a relay that logged this (see relay_rejected).
        self.assertIn("rejected after re-reading", self.log_text())

    def test_rotation_handled_by_retry_is_not_reported_as_rejected(self):
        self.connect()[1].close()
        self.proxy.password = "pw-2"
        self.set_proxy_url(f"http://muse:pw-2@127.0.0.1:{self.proxy.port}")
        self.connect()[1].close()
        self.assertNotIn("rejected after re-reading", self.log_text())

    def test_percent_encoded_password_is_decoded(self):
        self.proxy.password = "p@ss/w%rd"
        self.set_proxy_url(f"http://muse:p%40ss%2Fw%25rd@127.0.0.1:{self.proxy.port}")
        status, s = self.connect()
        s.close()
        self.assertIn(" 200 ", status)

    def test_proxy_url_pointing_at_the_relay_itself_is_refused(self):
        self.set_proxy_url(f"http://127.0.0.1:{self.port}")
        self.proxy.password = "pw-9"  # force the cached creds to fail and re-read
        status, s = self.connect()
        s.close()
        # The re-read gives the relay's own address, which it refuses to use;
        # the last good upstream answers 407 for the stale password.
        self.assertIn(" 407 ", status)
        self.assertIn("points at this relay", self.log_text())

    def test_never_logs_credentials(self):
        self.connect()[1].close()
        self.proxy.password = "pw-2"
        self.set_proxy_url(f"http://muse:pw-2@127.0.0.1:{self.proxy.port}")
        self.connect()[1].close()
        log = self.log_text()
        for secret in ("pw-1", "pw-2", self.proxy.token()):
            self.assertNotIn(secret, log)

    def test_log_is_owner_only(self):
        self.assertEqual(stat.S_IMODE(self.log.stat().st_mode), 0o600)


TOKEN = "5f" * 32


class RelayTokenTest(RelayTest):
    """With RELAY_TOKEN_FILE (pilot-up always sets it), the relay serves only
    clients whose Proxy-Authorization carries the token: another local user
    must not get the owner's proxy credentials stamped on its requests. The
    RelayTest cases above run again here with the token presented."""

    relay_env = {"RELAY_TOKEN_FILE": "{dir}/relay.token"}

    def start_relay(self, **extra):
        # The token file pilot-up would have written (relay_env's path).
        path = extra.get("RELAY_TOKEN_FILE")
        if path and path.endswith("/relay.token"):
            pathlib.Path(path).write_text(TOKEN + "\n")
        return super().start_relay(**extra)

    def connect(self, extra=b"", auth=True):
        if auth and b"proxy-authorization" not in extra.lower():
            cred = base64.b64encode(f"pilot-relay:{TOKEN}".encode())
            extra = b"Proxy-Authorization: Basic " + cred + b"\r\n" + extra
        return super().connect(extra)

    def test_stamps_fresh_credentials_and_strips_the_clients(self):
        # The client's own Proxy-Authorization is the token here: it is
        # checked, then replaced by the proxy's credentials.
        status, s = self.connect()
        with s:
            self.assertIn(" 200 ", status)
            s.sendall(b"ping")
            self.assertEqual(s.recv(4), b"ping")
        self.assertEqual(self.proxy.seen[-1], [f"Basic {self.proxy.token()}"])

    def test_client_without_the_token_is_refused_without_contacting_the_proxy(self):
        status, s = self.connect(auth=False)
        s.close()
        self.assertIn(" 407 ", status)
        self.assertEqual(self.proxy.seen, [])
        self.assertIn("denied CONNECT registry.pilotprotocol.network:443: no valid relay token",
                      self.log_text())

    def test_wrong_or_malformed_token_is_refused(self):
        for header in (b"Basic " + base64.b64encode(b"pilot-relay:wrong"),
                       b"Basic " + base64.b64encode(TOKEN.encode()),  # no user:pass
                       b"Basic !!!not-base64!!!",
                       b"Bearer " + TOKEN.encode()):
            with self.subTest(header=header):
                status, s = self.connect(b"Proxy-Authorization: " + header + b"\r\n")
                s.close()
                self.assertIn(" 407 ", status)
        self.assertEqual(self.proxy.seen, [])

    def test_any_user_name_with_the_token_is_accepted(self):
        cred = base64.b64encode(f"whoever:{TOKEN}".encode())
        status, s = self.connect(b"Proxy-Authorization: Basic " + cred + b"\r\n")
        s.close()
        self.assertIn(" 200 ", status)

    def test_token_never_logged(self):
        self.connect()[1].close()
        self.connect(auth=False)[1].close()
        log = self.log_text()
        self.assertNotIn(TOKEN, log)
        self.assertNotIn(base64.b64encode(f"pilot-relay:{TOKEN}".encode()).decode(), log)
        self.assertIn("clients must present the relay token", log)

    def test_unreadable_or_empty_token_file_stops_the_relay(self):
        for name, content in (("missing.token", None), ("empty.token", "\n")):
            with self.subTest(name=name):
                path = self.dir / name
                if content is not None:
                    path.write_text(content)
                self.port = free_port()
                proc = super().start_relay(RELAY_TOKEN_FILE=str(path))
                _, err = proc.communicate(timeout=10)
                self.assertNotEqual(proc.returncode, 0)
                self.assertIn(b"RELAY_TOKEN_FILE", err)
                with self.assertRaises(OSError):
                    socket.create_connection(("127.0.0.1", self.port), timeout=1).close()


if __name__ == "__main__":
    unittest.main()
