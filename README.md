# MahiFin

Native SwiftUI Jellyfin client for iOS 18+ and tvOS 18+. Original-only AVPlayer vertical slice, secure independent profiles, real catalog/search/details, EN/DA, iPhone original downloads/offline history and native AirPlay. **Implementation in progress, not a hardware-validated release.**

Private repository. No media/server credentials are required for CI. No MahiFin backend or analytics. No Swiftfin source is copied. See [provenance](THIRD_PARTY_NOTICES.md).

## Build on macOS

Xcode 16.4 is pinned in GitHub Actions; newer toolchains must retain OS 18 deployment targets.

```sh
python3 scripts/generate_project.py
python3 scripts/check_repository.py
cd Packages/MahiFinCore
swift test
cd ../..
xcodebuild -project MahiFin.xcodeproj -scheme MahiFin-iOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MahiFin.xcodeproj -scheme MahiFin-tvOS -destination 'generic/platform=tvOS Simulator' CODE_SIGNING_ALLOWED=NO build
open MahiFin.xcodeproj
```

The checked-in project and schemes build without XcodeGen/CocoaPods/external runtime packages. After adding/removing Swift files, regenerate the project and commit the result. Fixture tests run on macOS; no live server traffic. Structural checks are not Swift tests.

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

Connect to a Jellyfin 10.10+ HTTPS endpoint, with password or Quick Connect. Add independent accounts in Settings. Apple TV chooses a profile on cold launch; iPhone remembers the last account. Tap a title for details, or Continue Watching for immediate playback. Native AVKit provides track controls and seeking. Only trusted server Intro/Outro segments produce skip controls.

Downloads accept one unambiguous original source with known size and a native-compatible format. They stay until manual deletion. Open the downloaded item directly in Downloads to play offline; no server lookup on that route. Per-account history persists and retries when online. Wi-Fi is default; optional cellular policy persists. iOS determines background/force-quit behavior.

## Known limits and next gates

- No server conversion URL is issued. Policy distinguishes remux, audio-only and video-consent routes, but those execution paths are unavailable. Unsupported originals produce an error.
- Cast sender/receiver authorization and alternative local engine remain release blockers. Settings states this explicitly; no simulated discovery/connection controls.
- HDR is conservatively blocked pending verified route capability; Dolby Vision, TrueHD/DTS, external subtitles, full Jellyfin subtitle preference semantics and passthrough are not guaranteed.
- Apple builds do not prove actual Jellyfin compatibility, remote focus polish, background file transfer, 4K/HDR, soundbar sync or AirPlay.
- Durable offline replay uses partial absolute user-data writes. Server/client clock ambiguity and a fetch/post concurrency window remain documented limits; replay does not increment play counts.
- Native onboarding UI smoke tests run on OS 18 iOS/tvOS simulators. Catalog/playback/download UI coverage, comprehensive lifecycle tests and hardware validation remain additional gates.

Resume from [PROGRESS.md](PROGRESS.md) and Git history. [Implementation decisions](docs/IMPLEMENTATION_DECISIONS.md), [acceptance status](docs/IMPLEMENTATION_STATUS.md), [exact manual repros](docs/MANUAL_TESTS.md), and the original [product contract](docs/PRODUCT_SPEC.md) document remaining work.
