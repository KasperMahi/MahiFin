# MahiFin

Native SwiftUI Jellyfin client for iOS 18+ and tvOS 18+. Native AVPlayer plus pinned official VLCKit original playback, consent-controlled server conversion, secure independent profiles, real catalog/search/details, EN/DA, iPhone original downloads/offline history and native AirPlay. **Implementation in progress, not a hardware-validated release.**

Private repository. No media/server credentials are required for CI. No MahiFin backend or analytics. No Swiftfin source is copied. See [provenance](THIRD_PARTY_NOTICES.md).

## Build on macOS

Xcode 16.4 is pinned in GitHub Actions; newer toolchains must retain OS 18 deployment targets.

```sh
python3 scripts/generate_project.py
python3 scripts/check_repository.py
python3 scripts/generate_media.py # Requires ffmpeg; authored synthetic test clips only
cd Packages/MahiFinCore
swift test
cd ../..
xcodebuild -project MahiFin.xcodeproj -scheme MahiFin-iOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MahiFin.xcodeproj -scheme MahiFin-tvOS -destination 'generic/platform=tvOS Simulator' CODE_SIGNING_ALLOWED=NO build
open MahiFin.xcodeproj
```

The checked-in project builds without XcodeGen/CocoaPods. SwiftPM resolves checksum-pinned official VLCKit for both apps and Google Cast 4.8.6 for iOS only; GTMSessionFetcher is pinned to 3.0.0. Network access is needed for initial dependency resolution. After adding/removing app source files, regenerate the project and commit the result. Core fixture tests make no live server requests. Run `python3 scripts/simulator_smoke.py` on macOS with OS 18 simulators for onboarding, synthetic MKV and consent UI coverage. Structural checks are not Swift tests.

## Windows + GitHub workflow

```powershell
git clone https://github.com/KasperMahi/MahiFin.git
Set-Location MahiFin
git switch codex/initial-implementation
python scripts/generate_project.py
python scripts/check_repository.py
git push
```

Windows cannot build Apple targets. Inspect [Apple CI](https://github.com/KasperMahi/MahiFin/actions/workflows/apple.yml) for actual Swift test/build results. macOS CI uses unsigned simulator destinations; no Apple membership/signing secrets required. Select the target development team in Xcode locally for physical-device signing. Enroll for tvOS distribution/TestFlight later. Never commit signing assets. CI does not purchase quota or alter billing.

## Using the app

Connect to a Jellyfin 10.10+ HTTPS endpoint, with password or Quick Connect. Add independent accounts in Settings. Apple TV chooses a profile on cold launch; iPhone remembers the last account. Tap a title for details, or Continue Watching for playback. Automatic engine selection prefers native originals, then supported SDR originals in VLCKit, then server copy remux/audio conversion. Settings can prefer native or alternative playback. Both players expose seeking and embedded track selection. Only trusted server Intro/Outro segments produce skip controls.

Downloads accept one unambiguous original source with known size and a locally supported format, including SDR MKV through VLCKit. They stay until manual deletion. Open the downloaded item directly in Downloads to play offline; no server lookup on that route. Per-account resume snapshots survive successful upload; the separate durable queue retries when online. Wi-Fi is default; optional cellular policy persists. iOS determines background/force-quit behavior.

## Known limits and next gates

- Remux/audio-only HLS requests explicitly use `VideoCodec=copy`, exclude subtitle burn-in and omit video resize/bitrate constraints. Video encoding requires a new, expiring account/item/source consent grant from the UI. Live Jellyfin/ffmpeg execution and stream compatibility remain pending; request fixtures do not prove server execution.
- Official iOS Cast discovery/session controls are integrated. **Jellyfin media authorization/load is blocked:** audited receiver code logs credential envelopes and can negotiate conversion independently. This sender sends no receiver token envelope. Existing receiver media resume/seek requires confirmation because a receiver restart may encode video. See the decision record for the exact receiver repair and device tests required.
- Native HDR eligibility uses actual Apple HDR modes and HEVC decoding plus known Main10 metadata. Physical HDR output, Dolby Vision, TrueHD/DTS output, external subtitles, full Jellyfin subtitle preference semantics and passthrough are not verified. Local VLC HDR is not assumed.
- VLCKit public binary distribution remains gated on exact corresponding sources/build notices and LGPL replacement/relinking materials; Google binary terms/privacy review is also required. License text and pinned provenance are retained.
- Apple builds do not prove actual Jellyfin compatibility, remote focus polish, background file transfer, 4K/HDR, soundbar sync or AirPlay.
- Durable offline replay uses partial absolute user-data writes. Server/client clock ambiguity and a fetch/post concurrency window remain documented limits; replay does not increment play counts.
- CI distinguishes unsigned builds, core fixtures and real simulator runtime tests. Current evidence and any failed-run limitations are recorded in the acceptance matrix. Catalog/download UI coverage and hardware validation remain additional gates.

Resume from [PROGRESS.md](PROGRESS.md) and Git history. [Implementation decisions](docs/IMPLEMENTATION_DECISIONS.md), [acceptance status](docs/IMPLEMENTATION_STATUS.md), [exact manual repros](docs/MANUAL_TESTS.md), and the original [product contract](docs/PRODUCT_SPEC.md) document remaining work.
