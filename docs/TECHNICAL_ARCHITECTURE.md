# MahiFin — Technical architecture and technical risk register

## Architecture baseline (proposal, to validate in Codex audit)

Monorepo, Swift + SwiftUI, shared Swift Package(s) for Jellyfin domain/data, account store, metadata, catalog, playback decision engine, progress sync, security and diagnostics; separate iOS and tvOS app targets for platform UX. Native AVPlayer/AVKit first *when metadata allows*, pluggable alternative playback adapter e.g. VLC/SwiftVLC and server remux adapter. iOS-only Google Cast, AirPlay and offline download modules. Dependency injection supports mocks, integration servers and reproducible tests.

Suggested modules:

```
MahiFin/
  Apps/iOS/
  Apps/tvOS/
  Packages/MahiFinCore/Sources/{Domain,Jellyfin,Auth,Catalog,PlaybackPolicy,History,Diagnostics}
  Packages/MahiFinCore/Tests/
  Packages/MahiFinMedia/Sources/{AVPlayerAdapter,AlternativePlayerAdapter}
  Packages/MahiFinMobile/Sources/{Cast,OfflineDownloads,AirPlay}
  Resources/{en.lproj,da.lproj}/
  TestFixtures/{Jellyfin,MediaMetadata}/
  docs/
  .github/workflows/
```

These are conceptual boundaries, not mandatory directory names. Use actual buildable Xcode project/schemes over paper architecture; use XcodeGen or Tuist only if it reliably works in CI and is documented.

## Compatibility and SDK

- Server's actual Jellyfin version is currently **unknown**. Implement a Public System Info / capability handshake. Decide and document minimum supported Jellyfin server version rather than assuming latest SDK equals server version.
- Official Swift SDK https://github.com/jellyfin/jellyfin-sdk-swift — use if API compatibility is validated. Version 3.0 was generated for Jellyfin 12.0; ensure calls remain valid on the household's actual server or implement a slim compatibility boundary. Avoid speculative API signatures; compile and test.
- Swiftfin https://github.com/jellyfin/Swiftfin is MPL-2.0. As of 2026-10-14, current HEAD README reports **iOS 18+; tvOS 26+; Jellyfin 12.0**. Do **not** wholesale fork main and assume tvOS 18 compatibility; instead inspect older compatible code / isolate portable components and audit transitive dependencies.
- When copying MPL-covered source, preserve notices, make covered file source available upon distribution, and track copied/modified file provenance in THIRD_PARTY_NOTICES.md. Unmodified external packages retain their own licenses. Clarify if commercial shipping later affects licenses; don't strip attribution.

## Playback architecture

Implement explicit decision output:

```
PlaybackDecision {
  source: Direct | Remux | AudioOnlyTranscode | VideoTranscodeRequiresConsent | Unsupported
  engine: NativeAVPlayer | AlternativeLocalPlayer | ReceiverCast
  sourceMediaId, reasonCodes[], expectedAudioPath, expectedSubtitlePath, diagnosticMetadata
}
```

The decision engine must not mutate Jellyfin stream URL to request video transcoding before user confirms. Diagnose codec compatibility based on actual metadata/profile; device profiles are facts to maintain with tests. No rule 'MKV => transcoding': MKV may be played locally by alternative engine, or remuxed (without video codec re-encode) depending on route.

Respect Apple's actual video/audio capability and external audio chain; do not claim passthrough of TrueHD/DTS or universal HDR playback. For HDR, prefer native path only when compatible metadata, device, OS, and container support verified. Capture HDR/SDR correctness and frame-rate switching as hardware test cases. Remux is CPU-light relative to video transcoding but may still be unavailable on restricted shared hosting; prefer client direct when possible. Audio-only conversion is server CPU work; limit use.

Progress reporter: session IDs, item IDs, positions (ticks/seconds), idempotent events, throttling, attempt best-effort flush on termination, never double-count a stop/completion event, mark watched according to server semantics.

## Google Cast technical spike (release blocker)

- Use official Google Cast iOS sender SDK and its lifecycle/session APIs.
- Obtain or verify Jellyfin receiver **application ID and command protocol**. The Jellyfin Cast receiver is included in Jellyfin server but its existence does NOT guarantee arbitrary sender compatibility or no extra receiver registration.
- Confirm authentication/stream URL strategy: receiver must fetch playable URL directly; token headers may be difficult for a receiver; never leak long-lived credentials in a public URL; use official supported method / scoped tokens if possible.
- iOS Info.plist: `NSLocalNetworkUsageDescription`, Bonjour `_googlecast._tcp`, receiver-specific service key according to SDK docs; fail with remediation guidance when permission denied.
- Test discovery, app startup, media load, play/pause/seek, subtitles, lost Wi-Fi, sender backgrounding, app relaunch and reporting back to Jellyfin.
- If receiver proves incompatible, leave a working iOS local playback path, file a blocker and implement an isolated receiver abstraction. Do not fake Cast success or silently omit it from requirements.

## Offline download technical spike

- Use URLSession background transfer for original media bytes. Keep a durable manifest per user (server id, item id, content metadata/version, container/codec, file location, checksum/size when practical, transfer state, last sync timestamps).
- Avoid an architecture that depends on a live streaming transcode URL. Use original-file endpoint if server permissions and HTTP semantics permit. Verify range/resume and authenticated background headers.
- For unsupported local playback containers, route to alternative engine; warn before downloading when local playback is uncertain. This does not authorize server video transcoding.
- Store user tokens in Keychain; avoid cache/download path traversal and cross-profile access. Handle file protection and device backup policy thoughtfully.
- Offline sync should use event UUIDs, item scoped latest-write-wins semantics, durable retry/backoff, de-duplicate server posts, process conflicts deterministically. Client clock can be skewed; keep a monotonic sequence plus timestamp, and never claim global causal ordering beyond available data.

## Security and public release

- Enforce HTTPS by default with explicit and clearly warned developer-only exceptions for local HTTP (if implemented), do not globally disable ATS or certificate validation.
- No hard-coded credentials, server addresses, media data, instrumentation tokens or API keys in sources/workflows/tests. Use repository secrets ONLY for future release signing; never print them.
- Data privacy: solely on-device app and user's Jellyfin; analytics off. Redact auth tokens/URLs, sensitive filenames, account names in exported diagnostics.
- Third-party content and trademarks: no redistributed film posters/test media except appropriately licensed fixtures. No suggestion of official Jellyfin affiliation.
- For future public App Store submission: branding/rights, privacy disclosure, functional demo credentials/review mode, codec licensing, usage of any third-party player/SDK, and app review guidelines.

## Build, CI and release plan

- GitHub private repository. Standard macOS GitHub Actions runners available; private repositories use included quota and can incur charges if exceeded.
- Require successful unsigned iOS simulator and tvOS simulator builds, unit tests in shared Swift package, compile both app targets; run UI smoke tests on simulators only where reliable.
- Start with `CODE_SIGNING_ALLOWED=NO` for CI simulator builds. Configure fixed Xcode version compatible with chosen dependencies; no signing secrets until hardware/distribution phase.
- CI: format/lint, dependency license audit, unit/integration fixture tests, iOS/tvOS build, tests, summarize artifacts/logs; no live Jellyfin traffic or media asset transfer by default.
- After Apple Developer enrollment, use signing and TestFlight to validate physical Apple TV/iPhone. TestFlight builds expire after 90 days; long-term installation requires App Store distribution or ongoing signed distribution.
- Apple Developer membership expiration removes apps from new App Store downloads while already-installed App Store apps continue functioning; plan recurring membership if public distribution and updates matter.

## Risk register (descending impact)

| Risk | Severity | Mitigation / exit test |
|---|---|---|
| 4K/HDR accuracy without real Apple TV test | Critical | Real HDR sample/display and native pipeline validation before promising quality |
| Playback fallback lacks audio sync or subtitles | Critical | Real clips across codec matrix; selectable fallback; seek and session replay tests |
| Legacy Chromecast receiver interop/auth | Critical | Sender/receiver protocol spike; real 1st/2nd/3rd gen Cast smoke test |
| Jellyfin API version mismatch | High | Version handshake; test 10.10/10.11/12 as feasible; do not assume newest SDK |
| Apple tvOS18 vs Swiftfin main tvOS26 | High | Selectively reuse compatible modules, never blind fork |
| Secure offline original download/background constraints | High | iPhone airplane mode, background/kill scenarios, cross-account isolation |
| Server shared CPU/transcode policy violated | High | No silent video transcoding; telemetry of selected route in local diagnostics |
| GitHub macOS build passes but hardware fails | High | Explicit hardware gate; no 'production ready' from CI alone |
| MPL/third-party license compliance | Medium-high | Notices, dependency license manifest and source availability plan |
| Soundbar HDMI ARC/CEC intermittent output | Outside app control | Document Apple TV vs TV speaker settings, verify app does not produce codec/mute errors |
