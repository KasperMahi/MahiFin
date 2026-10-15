# Disposable Jellyfin validation

Status: implemented harness, **not executed successfully yet**. GitHub runs [38708083391](https://github.com/KasperMahi/MahiFin/actions/runs/38708083391) (Linux) and [38708083376](https://github.com/KasperMahi/MahiFin/actions/runs/38708083376) (Apple) failed before runner assignment: no steps or logs. The startup annotation is unavailable through the connector. Do not interpret that failure as a Swift, ffmpeg or Jellyfin result. Windows has no running Linux Docker daemon or Swift compiler.

Owner subsequently confirmed the initial cause: **monthly GitHub Actions usage limit reached**. Capacity later returned for attempt 2: Apple run 38710060541 passed at 7d5b6ec; Linux ran and exposed actual harness failures. The initial startup-only blocker is historical. See PROGRESS.md for the current run and failure/repair evidence. No billing change was made.

## Reproduce

On an isolated Linux machine with Docker Engine, Python 3, OpenSSL and ffprobe, from the repository root:

```sh
python3 -m unittest discover -s scripts/integration -p 'test_*.py'
python3 scripts/integration/run.py --version 10.10.7
python3 scripts/integration/run.py --version 10.11.0
```

The same commands run in `.github/workflows/jellyfin-integration.yml` on Ubuntu 24.04. Matrix versions are initial **candidates**, not a compatibility claim. Pull failures, unsupported APIs and timeouts fail the job. Do not substitute an unrecorded latest image. Each successful run records the actual server version and immutable Jellyfin/Swift image digests; after the first green run, pin those verified digests in `run.py`. Add another version only after confirming its official image and repeating the complete suite. No Jellyfin 12 deployment has been validated.

The orchestrator uses [official Jellyfin containers](https://jellyfin.org/docs/general/installation/container/) and the [official Swift Docker runtime](https://www.swift.org/install/linux/docker/). It creates an internal network and a uniquely named CPU/memory-limited server. The Linux host reaches its validated private bridge address without publishing a port; a temporary trusted HTTPS proxy bound to loopback serves the production Swift client. Internal Docker networks do not expose the requested published port in this runner, which caused the original misleading synthetic-media failure. The proxy does not disable client certificate validation or add app ATS exceptions. Installed host FFmpeg authors H.264/AAC and H.264/FLAC MKVs containing color, silence and SRT; two authored episodes exercise next-up. Actual Jellyfin conversion still uses and audits server ffmpeg. Media is mounted read-only, Internet providers disabled, and the server network has no external egress. The test runner itself needs Internet for image/dependency installation.

Passwords, tokens, CA private key, raw ffmpeg logs and authenticated URLs stay in the temporary directory and are destroyed after container removal. Docker environment values are temporary test credentials only. Only `TestResults/IntegrationReports/*.json` is uploaded: version/digest, check names, codec choices, dimensions and process counts. Never upload the private probe JSON, server config, Docker inspect environment, raw logs or request URLs. A hard-killed local orchestrator may leave its uniquely named container/network and temporary directory: identify that invocation explicitly before removing only those resources. On GitHub the disposable hosted VM is discarded.

## Assertions and evidence boundaries

| Area | Real-server assertion in the harness | Still separate |
|---|---|---|
| Authentication/catalog | Password success/rejection, independent users, movies/shows/views/episodes/search/paging | Quick Connect, Keychain, broad server settings |
| History | Real UserData writes and reads, resume row, favourites preserved, other-user isolation, serialized Playing/Progress/Stopped, next-up | Actual player timing and cross-client races |
| Offline/lifecycle | Durable local snapshot after sync/reload; transport drops response **after** server commit and retries; next episode server result | App navigation/countdown, OS eviction, physical background execution |
| Downloads | Original size and source SHA256, actual HTTP 206 prefix/remainder reconstruction, completion integrity, cancellation of throttled server bytes; no ffmpeg started | URLSession background daemon/resume blobs, disk-full and airplane-mode device playback |
| Remux | Actual HLS initialization/segment, ffprobe, explicit video/audio copy, unchanged 3840x2160, no pixel filter/resize | Other codecs, frame rates, HDR, audible output |
| Audio conversion | Actual FLAC-to-AAC HLS, video copy and unchanged 3840x2160, no pixel processing | Broad audio layouts/passthrough |
| Consented video | Production URL rejects missing grant; explicit test-only grant permits H.264, output at most 1920x1080; active ffmpeg before DELETE and none afterward | Human UI tested separately; resulting visual quality/HDR |
| Cleanup | DELETE ActiveEncodings after every mode; bounded wait for zero ffmpeg processes, final disposable server removal | Network-loss/app termination cleanup on devices |

The Swift probe is an executable test target, never linked into either app. It uses the actual `MahiFinCore` transport, models, endpoint builders, history and consent boundary. It is not a simulator test or physical playback. A green inspector unit test only proves its rejection rules against authored arguments; only a green real-server report proves actual ffmpeg execution. The automated consent environment flag exists solely inside this disposable test harness and cannot authorize an app session.

## Resume after infrastructure failure

1. Confirm Actions capacity has returned after the monthly usage limit, or obtain an owner-authorized alternative runner. Do not disable checks or silently move to a paid runner. Inspect startup annotations only if failures persist after capacity returns.
2. Rerun both complete workflows on the current commit. Inspect private logs locally if needed; expose only allowlisted failure categories in artifacts. Fix actual compiler/API/encoding failures without weakening copy/consent assertions.
3. Record exact successful SHA, run links, image digests, counts and conversion results in PROGRESS/status. A pending probe or old Apple green run cannot establish current compatibility.
4. Repeat the manual UI/device procedures after real-server CI is green. Never infer physical HDR output or background-download reliability from Linux/simulator results.
