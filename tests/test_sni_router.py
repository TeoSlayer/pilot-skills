"""Tests for skills/pilot-sandbox/scripts/sni_router.py: proxy URL parsing,
credential redaction in everything it logs, and the CONNECT handshake.

    python3 -m unittest discover -s tests -p 'test_*.py'
"""
import base64
import contextlib
import io
import os
import socket
import sys
import threading
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "skills", "pilot-sandbox", "scripts"))
import sni_router  # noqa: E402


def client_hello(sni: str) -> bytes:
    """A minimal TLS ClientHello record carrying one server_name."""
    name = sni.encode()
    sni_list = b"\x00" + len(name).to_bytes(2, "big") + name
    sni_data = len(sni_list).to_bytes(2, "big") + sni_list
    ext = b"\x00\x00" + len(sni_data).to_bytes(2, "big") + sni_data
    body = (b"\x03\x03" + b"\x00" * 32 + b"\x00" + b"\x00\x02\x13\x01" + b"\x01\x00"
            + len(ext).to_bytes(2, "big") + ext)
    hs = b"\x01" + len(body).to_bytes(3, "big") + body
    return b"\x16\x03\x01" + len(hs).to_bytes(2, "big") + hs


class FakeProxy:
    """One-shot HTTP proxy on 127.0.0.1: records the CONNECT head, answers
    with a fixed status line."""

    def __init__(self, status: bytes):
        self.status = status
        self.request = b""
        self.srv = socket.socket()
        self.srv.bind(("127.0.0.1", 0))
        self.srv.listen(1)
        self.port = self.srv.getsockname()[1]
        self.thread = threading.Thread(target=self._serve, daemon=True)
        self.thread.start()

    def _serve(self):
        conn, _ = self.srv.accept()
        with conn:
            while b"\r\n\r\n" not in self.request:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                self.request += chunk
            conn.sendall(self.status + b"\r\n\r\n")
        self.srv.close()


def captured(fn, *args):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        result = fn(*args)
    return result, out.getvalue()


class ProxyParsing(unittest.TestCase):
    def test_default_ports(self):
        self.assertEqual(sni_router.Proxy("http://u:p@proxy.internal").port, 80)
        self.assertEqual(sni_router.Proxy("https://proxy.internal").port, 443)
        self.assertEqual(sni_router.Proxy("http://proxy:3128").port, 3128)

    def test_redacted(self):
        self.assertEqual(sni_router.Proxy("http://alice:s3cret@proxy:3128").redacted(), "http://***@proxy:3128")
        self.assertEqual(sni_router.Proxy("http://proxy:3128").redacted(), "http://proxy:3128")
        self.assertNotIn("s3cret", repr(sni_router.Proxy("http://alice:s3cret@proxy:3128")))

    def test_bad_urls_never_echo_the_secret(self):
        for url in ("http://user:pa/sswd@host:3128",   # '/' ends the authority early
                    "http://abcDEF/ghi@proxy:3128",     # credential parsed as the host
                    "http://user:secretpw?x@proxy:3128",
                    "socks5://user:secretpw@proxy:1080",
                    "http://user:secretpw@proxy:notaport"):
            with self.subTest(url=url):
                with self.assertRaises(ValueError) as cm:
                    sni_router.Proxy(url)
                msg = str(cm.exception)
                for part in ("sswd", "ghi", "secretpw", "user", "abcDEF"):
                    self.assertNotIn(part, msg)


class Scrub(unittest.TestCase):
    def test_userinfo_up_to_last_at(self):
        self.assertEqual(sni_router.scrub("dial http://alice:p@ss@proxy:3128 failed"),
                         "dial http://***@proxy:3128 failed")

    def test_every_form_of_the_secret(self):
        p = sni_router.Proxy("http://tok%40en:pa%2Fss@proxy:3128")
        token = base64.b64encode(b"tok@en:pa/ss").decode()
        text = f"a pa/ss b pa%2Fss c {token} d tok@en:pa/ss e http://tok%40en:pa%2Fss@proxy:3128"
        out = sni_router.scrub(text, p)
        for secret in ("pa/ss", "pa%2Fss", token, "tok@en:pa/ss"):
            self.assertNotIn(secret, out)
        self.assertIn("proxy:3128", out)

    def test_short_user_names_do_not_mask_hostnames(self):
        p = sni_router.Proxy("http://pilot:hunter22@proxy:3128")
        self.assertEqual(sni_router.scrub("routed SNI=registry.pilotprotocol.network", p),
                         "routed SNI=registry.pilotprotocol.network")


class Connect(unittest.TestCase):
    def test_sni_extraction(self):
        self.assertEqual(sni_router.extract_sni(client_hello("registry.pilotprotocol.network")),
                         "registry.pilotprotocol.network")
        self.assertIsNone(sni_router.extract_sni(b"GET / HTTP/1.1\r\n\r\n"))

    def test_connect_sends_decoded_credentials(self):
        fake = FakeProxy(b"HTTP/1.1 200 Connection established")
        p = sni_router.Proxy(f"http://tok%40en:pa%2Fss@127.0.0.1:{fake.port}")
        up, out = captured(sni_router.proxy_connect, p, "registry.pilotprotocol.network", 443)
        self.assertIsNotNone(up)
        up.close()
        fake.thread.join(5)
        head = fake.request.decode()
        self.assertTrue(head.startswith("CONNECT registry.pilotprotocol.network:443 HTTP/1.1\r\n"))
        self.assertIn("Proxy-Authorization: Basic " + base64.b64encode(b"tok@en:pa/ss").decode(), head)
        self.assertEqual(out, "")

    def test_refused_connect_is_logged_without_secrets(self):
        fake = FakeProxy(b"HTTP/1.1 407 Proxy Authentication Required")
        p = sni_router.Proxy(f"http://alice:s3cret-pw@127.0.0.1:{fake.port}")
        up, out = captured(sni_router.proxy_connect, p, "beacon.pilotprotocol.network", 443)
        self.assertIsNone(up)
        self.assertIn("407", out)
        self.assertNotIn("s3cret-pw", out)
        self.assertNotIn(base64.b64encode(b"alice:s3cret-pw").decode(), out)

    def test_handle_error_is_logged_without_secrets(self):
        # A proxy port with nothing listening: the dial error goes to the log.
        s = socket.socket()
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
        s.close()
        p = sni_router.Proxy(f"http://alice:s3cret-pw@127.0.0.1:{port}")
        client, server = socket.socketpair()
        client.sendall(client_hello("registry.pilotprotocol.network"))
        _, out = captured(sni_router.handle, server, p)
        client.close()
        self.assertIn("handle error", out)
        self.assertNotIn("s3cret-pw", out)


if __name__ == "__main__":
    unittest.main()
