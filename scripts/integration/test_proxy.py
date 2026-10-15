"""Real loopback TLS/framing tests; no Jellyfin or credential fixtures."""
import http.client
import http.server
import os
from pathlib import Path
import ssl
import subprocess
import tempfile
import threading
import unittest
from run import ROOT, proxy


class ProxyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        results = ROOT / "TestResults"
        results.mkdir(exist_ok=True)
        cls.work = tempfile.TemporaryDirectory(prefix="proxy-tls-", dir=results)
        root = Path(cls.work.name)
        cls.certificate, key = root / "ca.crt", root / "key.pem"
        subprocess.run([os.environ.get("MAHIFIN_TEST_OPENSSL", "openssl"), "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", cls.certificate, "-days", "1", "-subj", "/CN=MahiFinProxyTest", "-addext", "subjectAltName=IP:127.0.0.1"], check=True, capture_output=True, timeout=30)
        cls.payload = bytes(range(256)) * 100

        class Upstream(http.server.BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *_):
                pass

            def do_GET(self):
                self.send_response(200)
                if self.path == "/length":
                    self.send_header("Content-Length", str(len(cls.payload)))
                    self.end_headers()
                    self.wfile.write(cls.payload)
                else:
                    self.send_header("Transfer-Encoding", "chunked")
                    self.end_headers()
                    for part in (cls.payload[:1000], cls.payload[1000:]):
                        self.wfile.write(f"{len(part):X}\r\n".encode() + part + b"\r\n")
                    self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()

        cls.upstream = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
        threading.Thread(target=cls.upstream.serve_forever, daemon=True).start()
        cls.proxy = proxy(f"http://127.0.0.1:{cls.upstream.server_port}", cls.certificate, key)

    @classmethod
    def tearDownClass(cls):
        cls.proxy.shutdown(); cls.proxy.server_close()
        cls.upstream.shutdown(); cls.upstream.server_close()
        cls.work.cleanup()

    def fetch(self, path):
        connection = http.client.HTTPSConnection("127.0.0.1", self.proxy.server_port,
            context=ssl.create_default_context(cafile=str(self.certificate)), timeout=5)
        try:
            connection.request("GET", path)
            response = connection.getresponse()
            data = response.read()
            self.assertEqual(response.status, 200)
            self.assertEqual(data, self.payload)
            self.assertEqual(response.version, 11)
            return response
        finally:
            connection.close()

    def test_chunked_tls_body_has_explicit_terminal_framing(self):
        response = self.fetch("/chunked")
        self.assertEqual(response.getheader("Transfer-Encoding"), "chunked")
        self.assertIsNone(response.getheader("Content-Length"))

    def test_known_length_tls_body_preserves_original_bytes(self):
        response = self.fetch("/length")
        self.assertEqual(response.getheader("Content-Length"), str(len(self.payload)))
        self.assertIsNone(response.getheader("Transfer-Encoding"))


if __name__ == "__main__":
    unittest.main()
