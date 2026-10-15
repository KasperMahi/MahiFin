"""Disposable Linux-only real Jellyfin integration. Never exports raw logs/secrets."""
import argparse
import hashlib
import http.client
import http.server
import ipaddress
import json
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from ffmpeg_audit import audit, command_from_log

ROOT = Path(__file__).resolve().parents[2]
VERSIONS = {"10.10.7": "jellyfin/jellyfin:10.10.7", "10.11.0": "jellyfin/jellyfin:10.11.0"}
SWIFT = "swift:6.1.2-jammy"


class Failure(Exception):
    pass


def check(value, code):
    if not value:
        raise Failure(code)


def command(args, timeout=300, setup_diagnostics=False):
    try:
        result = subprocess.run([str(a) for a in args], capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        if setup_diagnostics:
            print(f"INTEGRATION: fixture setup timeout after {timeout}s", flush=True)
        raise Failure("bounded subprocess timeout") from None
    if result.returncode:
        if setup_diagnostics:
            # Only authored fixtures / Docker setup, before password creation.
            # Never enable for server/API/Swift commands containing private data.
            import re
            print(f"INTEGRATION: fixture setup exit={result.returncode}", flush=True)
            for line in result.stderr.decode(errors="replace").splitlines()[-12:]:
                if re.search(r"api_key|accessToken|Authorization|password", line, flags=re.I):
                    line = "[sensitive diagnostic omitted]"
                line = re.sub(r"[a-zA-Z][a-zA-Z0-9+.-]*://\S+", "[URL]", line)
                print("INTEGRATION: setup stderr: " + line[:300], flush=True)
        for line in result.stdout.decode(errors="replace").splitlines():
            if line.startswith("INTEGRATION:"):
                print(line, flush=True)
        # Compiler diagnostics contain source locations, not runtime request values.
        if args[0] == "docker" and "swift run" in str(args[-1]):
            for line in result.stderr.decode(errors="replace").splitlines():
                if "error:" in line and "api_key" not in line:
                    print(line[:500], flush=True)
        raise Failure("subprocess failed: " + str(args[0]))
    return result.stdout


class API:
    def __init__(self, base, token=None, ca=None):
        self.base, self.token = base, token
        self.context = ssl.create_default_context(cafile=str(ca)) if ca else None

    def send(self, path, method="GET", body=None, headers=None):
        url = path if path.startswith("https://") else self.base + "/" + path
        check(urllib.parse.urlsplit(url).netloc == urllib.parse.urlsplit(self.base).netloc, "cross-origin test URL")
        values = {"Content-Type": "application/json", "Authorization": 'MediaBrowser Client="MahiFinIntegration", Device="Disposable", DeviceId="setup", Version="1"'}
        if self.token:
            values["X-Emby-Token"] = self.token
        values.update(headers or {})
        request = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=values, method=method)
        try:
            with urllib.request.urlopen(request, timeout=90, context=self.context) as response:
                return response.read(), response.status
        except urllib.error.HTTPError as error:
            raise Failure(f"HTTP status {error.code}") from None

    def json(self, path, method="GET", body=None):
        data, _ = self.send(path, method, body)
        return json.loads(data) if data else None


def proxy(upstream, certificate, key):
    address = urllib.parse.urlsplit(upstream)

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass  # URLs can carry api_key. Never use the default access logger.

        def forward(self):
            connection = http.client.HTTPConnection(address.hostname, address.port, timeout=90)
            try:
                body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
                slow = self.headers.get("X-MahiFin-Test-Slow") == "1"
                headers = {k: v for k, v in self.headers.items() if k.lower() not in {"host", "connection", "x-mahifin-test-slow"}}
                connection.request(self.command, self.path, body=body or None, headers=headers)
                response = connection.getresponse()
                self.send_response(response.status)
                for name, value in response.getheaders():
                    if name.lower() not in {"connection", "transfer-encoding", "server", "date"}:
                        self.send_header(name, value)
                self.end_headers()
                while chunk := response.read(16384):
                    self.wfile.write(chunk); self.wfile.flush()
                    if slow:
                        time.sleep(0.02)  # Network fault harness, not a fake Jellyfin response.
            except (BrokenPipeError, ConnectionResetError, TimeoutError):
                pass
            finally:
                connection.close()

        do_GET = do_POST = do_DELETE = do_HEAD = forward

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certificate, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def media(work):
    root = work / "media"
    movies, series = root / "Movies", root / "Series" / "Fixture Series" / "Season 01"
    movies.mkdir(parents=True); series.mkdir(parents=True)
    (root / "source.srt").write_text("1\n00:00:01,000 --> 00:00:08,000\nAuthored synthetic subtitle\n")
    # Fixture authoring is independent of Jellyfin's runtime ffmpeg. CI already
    # installs host ffmpeg/ffprobe; server conversion is still audited separately.
    ffmpeg = ["ffmpeg", "-nostdin"]
    for title, size, codec in [("Fixture Original", "256x144", "aac"), ("Fixture Copy 4K", "3840x2160", "aac"), ("Fixture Audio 4K", "3840x2160", "flac")]:
        folder = movies / title; folder.mkdir()
        output = folder / f"{title}.mkv"
        command(ffmpeg + ["-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i", f"color=c=blue:s={size}:r=1:d=900", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-i", root / "source.srt", "-map", "0:v", "-map", "1:a", "-map", "2:s", "-c:v", "libx264", "-preset", "ultrafast", "-threads", "2", "-pix_fmt", "yuv420p", "-c:a", codec, "-c:s", "srt", "-t", "900", output], timeout=600, setup_diagnostics=True)
        (folder / f"{title}.nfo").write_text(f"<movie><title>{title}</title><year>2020</year></movie>")
    import shutil
    for number in (1, 2):
        name = f"Fixture Series - S01E0{number}"
        shutil.copyfile(movies / "Fixture Original/Fixture Original.mkv", series / f"{name}.mkv")
        (series / f"{name}.nfo").write_text(f"<episodedetails><title>Fixture Episode {number}</title><season>1</season><episode>{number}</episode><aired>2020-01-0{number}</aired></episodedetails>")
    (series.parent / "tvshow.nfo").write_text("<tvshow><title>Fixture Series</title></tvshow>")
    return root


def wait_until(test, seconds=180):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            value = test()
            if value:
                return value
        except (Failure, urllib.error.URLError, ConnectionError):
            pass
        time.sleep(1)
    raise Failure("bounded readiness timeout")


def process_argv(name):
    # NUL-separated actual /proc argv, never printed/exported verbatim.
    script = 'for f in /proc/[0-9]*/comm; do read -r n < "$f"; if [ "$n" = ffmpeg ]; then cat "${f%/comm}/cmdline"; printf "\\n@@\\n"; fi; done'
    raw = command(["docker", "exec", name, "sh", "-c", script])
    return [[s.decode() for s in record.split(b"\0") if s] for record in raw.split(b"\n@@\n") if record.strip()]


def hls_output(api, url, work):
    data, status = api.send(url)
    check(status == 200, "HLS master status")
    lines = data.decode().splitlines()
    variant = next((line for line in lines if line and not line.startswith("#")), None)
    check(variant is not None, "HLS playlist has no URI")
    playlist_url = urllib.parse.urljoin(url, variant)
    playlist, _ = api.send(playlist_url)
    text = playlist.decode()
    import re
    init = re.search(r'#EXT-X-MAP:URI="([^"]+)"', text)
    check(init is not None, "expected fragmented MP4 initialization map")
    segment = next((line for line in text.splitlines() if line and not line.startswith("#")), None)
    check(segment is not None, "HLS segment missing")
    prefix = api.send(urllib.parse.urljoin(playlist_url, init.group(1)))[0] if init else b""
    fragment = api.send(urllib.parse.urljoin(playlist_url, segment))[0]
    path = work / "segment.mp4"
    path.write_bytes(prefix + fragment)
    return json.loads(command(["ffprobe", "-v", "error", "-show_streams", "-of", "json", path]))["streams"]


def run(version, report):
    image = VERSIONS[version]
    phase = "environment"
    name = "mahifin-integration-" + uuid.uuid4().hex[:12]
    probe_name = name + "-probe"
    network = name + "-network"
    report.update(version=version, evidence="real-disposable-jellyfin-linux", checks=[], conversions=[])
    command(["docker", "info", "--format", "{{.ServerVersion}}"])
    with tempfile.TemporaryDirectory(prefix="mahifin-integration-") as folder:
        work = Path(folder)
        proxy_server = None
        try:
            phase = "pull-images"
            for value in (image, SWIFT):
                command(["docker", "pull", value], timeout=600)
            report["server_image"] = json.loads(command(["docker", "image", "inspect", image]))[0]["RepoDigests"][0]
            report["swift_image"] = json.loads(command(["docker", "image", "inspect", SWIFT]))[0]["RepoDigests"][0]
            phase = "synthetic-media"
            source = media(work)
            config, cache, private = work / "config", work / "cache", work / "private"
            for path in (config, cache, private):
                path.mkdir()
            phase = "docker-network"
            command(["docker", "network", "create", "--internal", network], setup_diagnostics=True)
            phase = "docker-start"
            command(["docker", "run", "-d", "--name", name, "--user", f"{os.getuid()}:{os.getgid()}", "--network", network, "--cpus", "2", "--memory", "3g", "-v", f"{source}:/media:ro", "-v", f"{config}:/config", "-v", f"{cache}:/cache", image], setup_diagnostics=True)
            phase = "docker-address"
            # Internal bridges do not publish ports. The Linux host can reach
            # its private bridge directly; no host listener or Internet egress.
            address = command(["docker", "inspect", "--format", "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", name], setup_diagnostics=True).decode().strip()
            parsed = ipaddress.IPv4Address(address)
            check(parsed.is_private and not (parsed.is_loopback or parsed.is_unspecified or parsed.is_multicast), "expected private Docker bridge address")
            bootstrap = API(f"http://{address}:8096")
            phase = "server-startup"
            actual = wait_until(lambda: bootstrap.json("System/Info/Public"))
            check(actual["Version"] == version, "unexpected deployed version")
            report["actual_version"] = actual["Version"]
            password, other_password = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
            bootstrap.json("Startup/Configuration", "POST", {"UICulture": "en-US", "MetadataCountryCode": "US", "PreferredMetadataLanguage": "en"})
            bootstrap.json("Startup/User", "POST", {"Name": "fixture-owner", "Password": password})
            bootstrap.json("Startup/RemoteAccess", "POST", {"EnableRemoteAccess": False, "EnableAutomaticPortMapping": False})
            bootstrap.json("Startup/Complete", "POST")
            auth = bootstrap.json("Users/AuthenticateByName", "POST", {"Username": "fixture-owner", "Pw": password})
            admin = API(bootstrap.base, auth["AccessToken"])
            admin.json("Users/New", "POST", {"Name": "fixture-other", "Password": other_password})
            phase = "library-scan"
            for title, kind, path in [("Fixture Movies", "movies", "/media/Movies"), ("Fixture Shows", "tvshows", "/media/Series")]:
                query = urllib.parse.urlencode({"name": title, "collectionType": kind, "refreshLibrary": "false", "paths": path})
                admin.json("Library/VirtualFolders?" + query, "POST", {"LibraryOptions": {"EnableInternetProviders": False, "EnableRealtimeMonitor": False, "EnableChapterImageExtraction": False, "ExtractChapterImagesDuringLibraryScan": False, "EnableTrickplayImageExtraction": False}})
            admin.json("Library/Refresh", "POST")
            query = "Items?Recursive=true&IncludeItemTypes=Movie,Episode&UserId=" + auth["User"]["Id"]
            wait_until(lambda: len(admin.json(query)["Items"]) == 5)
            phase = "trusted-loopback-tls"
            certificate, key = private / "ca.crt", private / "key.pem"
            command(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", certificate, "-days", "1", "-subj", "/CN=MahiFinDisposable", "-addext", "subjectAltName=IP:127.0.0.1,DNS:localhost"])
            proxy_server = proxy(bootstrap.base, certificate, key)
            base = "https://127.0.0.1:" + str(proxy_server.server_port)
            values = {"MAHIFIN_DISPOSABLE": "1", "MAHIFIN_TEST_SERVER": base, "MAHIFIN_TEST_PASSWORD": password, "MAHIFIN_OTHER_PASSWORD": other_password, "MAHIFIN_PRIVATE_OUTPUT": "/integration", "MAHIFIN_TEST_ACCEPT_VIDEO": "1"}
            envfile = private / "environment"
            envfile.write_text("".join(f"{k}={v}\n" for k, v in values.items()))
            phase = "swift-production-client"
            # CA installation needs root inside this disposable container. Return
            # generated private files to the host owner without widening permissions.
            script = f"trap 'chown -R {os.getuid()}:{os.getgid()} /integration' EXIT; cp /integration/ca.crt /usr/local/share/ca-certificates/mahifin-test.crt && update-ca-certificates >/dev/null && swift run --package-path /workspace --scratch-path /tmp/mahifin-build MahiFinIntegrationProbe"
            args = ["docker", "run", "--rm", "--name", probe_name, "--network", "host", "--env-file", envfile, "-v", f"{ROOT / 'Packages/MahiFinCore'}:/workspace:ro", "-v", f"{private}:/integration", SWIFT, "bash", "-c", script]
            command(args, timeout=600)
            result = json.loads((private / "probe-private.json").read_text())
            report["checks"] += result["checks"]
            check(hashlib.sha256((private / "download-original.mkv").read_bytes()).digest() == hashlib.sha256((source / "Movies/Fixture Original/Fixture Original.mkv").read_bytes()).digest(), "original byte hash mismatch")
            check(not process_argv(name), "metadata/history/download unexpectedly started ffmpeg")
            report["checks"].append("real-original-sha256-no-prior-ffmpeg")
            api = API(base, result["token"], certificate)
            for mode in ("remux", "audioOnly", "video"):
                phase = "ffmpeg-" + mode
                before = set(config.glob("log/FFmpeg*"))
                streams = hls_output(api, result["urls"][mode], private)
                logs = wait_until(lambda: list(set(config.glob("log/FFmpeg*")) - before), seconds=30)
                audits = [audit(command_from_log(path.read_text(errors="replace")), mode, streams) for path in logs if path.is_file()]
                check(bool(audits), "no actual ffmpeg log evidence")
                running = process_argv(name)
                if mode == "video":
                    check(bool(running), "video already ended before cancellation evidence")
                api.send(result["urls"][mode + "Cleanup"], "DELETE")
                wait_until(lambda: not process_argv(name), seconds=30)
                for item in audits:
                    item["active_before_cleanup"] = bool(running)
                    item["processes_after_cleanup"] = 0
                    report["conversions"].append(item)
            report["checks"].append("real-ffmpeg-copy-audio-video-output-and-active-cancellation")
            report["passed"] = True
        except Exception as error:
            report["passed"] = False
            report["failed_phase"] = phase
            # Never include arbitrary exception text/server bodies/URLs in the artifact.
            report["failure_type"] = type(error).__name__
            if isinstance(error, Failure):
                print("INTEGRATION FAILED:", phase, str(error), flush=True)
            else:
                print("INTEGRATION FAILED:", phase, type(error).__name__, flush=True)
        finally:
            if proxy_server:
                proxy_server.shutdown(); proxy_server.server_close()
            # Only names generated in this invocation. No shared containers/volumes touched.
            subprocess.run(["docker", "rm", "-f", probe_name], capture_output=True)
            subprocess.run(["docker", "rm", "-f", name], capture_output=True)
            subprocess.run(["docker", "network", "rm", network], capture_output=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=VERSIONS, required=True)
    args = parser.parse_args()
    if sys.platform != "linux":
        raise SystemExit("Run this disposable Docker harness on Linux; no Windows Docker/Desktop state is modified")
    evidence = {}
    run(args.version, evidence)
    destination = ROOT / "TestResults/IntegrationReports"
    destination.mkdir(parents=True, exist_ok=True)
    (destination / (args.version + ".json")).write_text(json.dumps(evidence, indent=2) + "\n")
    print("INTEGRATION:", args.version, "passed" if evidence.get("passed") else "FAILED", flush=True)
    raise SystemExit(0 if evidence.get("passed") else 1)
