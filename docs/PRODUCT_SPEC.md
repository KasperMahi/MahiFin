# MahiFin — Product requirements (v1.0)

**Date:** 2026-10-14  
**Stage:** User-approved functional requirements; technical implementation unvalidated.  
**Platforms:** iOS 18+ (iPhone), tvOS 18+ (Apple TV). Not Android/iPad-specific in v1. May work on iPad if easily supported but not a release gate.  
**Audience:** Initially private household use, with an architecture suitable for potential public App Store release and connection to arbitrary Jellyfin servers.  
**Working name:** MahiFin; check naming and trademark before public release.

## Product principles

1. A non-technical household member must be able to start watching in a few clicks.
2. Avoid media transcoding on shared Jellyfin servers, especially 4K video. Direct Play preferred; no silent video transcoding.
3. Reliability over feature quantity: resume, watched status, audio, 4K/HDR, seeking, and remote interactions matter most.
4. Reuse proven components and SDKs when licenses and technical fit permit, without inheriting unnecessarily complex interfaces.
5. Support independent Jellyfin users with strict separation of credentials, history and downloads.
6. No reliance on a proprietary backend controlled by MahiFin; clients connect to the user's own Jellyfin server.

## Reference environment (not app-wide constraints)

- Apple TV 4K generation 3 (2022) with Philips soundbar/subwoofer through HDMI ARC/eARC. Exact soundbar model unknown. Soundbar sometimes misbehaves (silence, simultaneous TV/soundbar output); do not assume the app can correct external HDMI-CEC/ARC faults.
- Older Chromecast (1st/2nd/3rd generation; precise device to verify on hardware).
- Jellyfin deployed on Ultra.cc Steel shared hosting, reachable at an HTTPS endpoint from outside the home. No guarantee of dedicated hardware transcoding.
- Library largely H.264, assorted audio codecs. Container mix and actual HDR profiles unknown; must probe metadata, not assume all files are MKV or H.264.
- Some family members use legacy devices without HEVC support. **Do not require changing the existing library to HEVC.** MahiFin itself should support HEVC where technically possible.

## Information architecture

Main navigation:
- Home
- Films
- Series
- Search
- Settings
- Additional iPhone Downloads screen/section (may be visible as extra navigation item).

Home includes in this order: Continue Watching, Next Up/Next Episode, Recently Added. Use large art, poster rows, Netflix-inspired aesthetics; do not copy copyrighted Netflix brand assets/layout verbatim. Provide empty, loading, error and skeleton states.

Films and series:
- Poster grid, sorting, filtering by genre, release year, watched/unwatched, and source Jellyfin library.
- Combine same-type Jellyfin libraries under the Films or Series entry; allow library filter.
- Single cross-library search for films and series.
- Film/series detail: backdrop, description, rating, cast, play/resume, seasons and episodes where relevant.
- Continue Watching offers one-click resume; other titles open detail page.
- Mark watched/unwatched, favourite/unfavourite via Jellyfin API.
- Skip-intro / skip-credits controls **only when Jellyfin exposes trusted markers**; never invent markers.
- Danish and English language based on system locale; fallback English for unknown locales. Localize errors/accessibility labels too.

## Authentication and profile handling

- Setup: user enters any Jellyfin server URL; prefer HTTPS, support Jellyfin Quick Connect and username/password fallback.
- Validate and persist multiple separate users on a single Jellyfin server. Allow future server switch/change and logout.
- Keep credentials/tokens in Apple Keychain. No credentials or token-bearing URLs in ordinary logs, crash reports, source control or analytics.
- **tvOS:** profile chooser at actual fresh app launch, not every return from background or short context switch. Multiple accounts remain logged in; one-click chooser. No password on switching already authenticated users.
- **iOS:** remember last active account; fast switch available from UI.
- Do not mix history/favourites/offline assets between profiles. Immediately refresh caches after a profile switch.
- Do not require or share the owner's actual server credentials in CI/tests. Use fixtures or a dedicated disposable integration-test account later.

## Playback requirements

Priority: stable 4K in original resolution, HDR10 and compatible HDR formats on supported hardware, correct audio output, seeking and native remote control, accurate resume. Do not claim HDR until tested on hardware using verified HDR media and display.

Playback selection policy:
1. Probe actual item metadata (container, video/audio codec, profiles, bitrate, HDR, subtitles, tracks) and device capabilities.
2. Prefer **Direct Play** of original stream when supported.
3. If format not supported by AVPlayer, prefer compatible **local alternative playback engine** (e.g. VLC-based) without server video conversion; or **remux** without video re-encoding, provided it works with hardware, subtitles and expected audio. Choose based on measured reliability.
4. Allow **audio-only server transcoding** when needed, avoiding video re-encoding.
5. **Require explicit user consent before any video transcoding**, including when initiated from Cast or by subtitle burn-in. Display reason/likely impact, with Cancel and Play with conversion. Never silently re-enable video transcoding after declined request.
6. If none work, show actionable error, source codec/path and diagnostic details, not an endless spinner.

Native Apple player interaction is preferred. The fallback player should preserve play/pause, skip, seeking, subtitles and available audio track selection as well as possible. Native AVPlayer cannot natively open arbitrary MKV and has track/codec constraints; ensure route-specific behaviour, not false guarantees.

Playback status/progress:
- Sync position periodically and on pause/seek/exit/completion to Jellyfin with sensible throttling.
- Automatically resume from server position when selecting Continue Watching.
- On episode completion, set correct watched status and Next Up; avoid marking watched on early abort.
- After episode completion show Next Episode countdown **5 seconds**, cancellable, then play automatically.
- Use profile's Jellyfin subtitle preferences by default, with manual subtitle/audio selection at playback time.
- Support trickplay/chapter features only where server supplies them; never break basic seeking.
- Offer hidden/optional Diagnostics: route, video/audio/subtitle codec, bitrate, container, HDR, transcoding decision, buffered duration/seek reason if exposed, stream errors and logs.

## Casting and remote playback (iPhone)

- Google Cast SDK device discovery, Cast session management, reconnection, playback controls (start, pause, seek, subtitle/audio if compatible, next), iPhone lock-screen/background behaviour as permitted.
- Work toward integration with Jellyfin's existing Cast web receiver; **receiver application ID, allowed sender protocol and compatibility must be verified, not presumed**.
- Cast device must be able to reach stream endpoint itself over HTTPS (local discoverability is separate from media accessibility).
- Legacy Chromecast cannot handle many HEVC/4K streams; before needed video transcoding, **ask**. Respect user cancellation.
- AirPlay supported using platform mechanisms; distinguish direct AirPlay output from remote Jellyfin session control.
- iPhone-to-Apple TV remote control is explicitly out of scope for first version.

## Offline downloads (iPhone v1)

- Download **original source file only**; no server-side transcoding for downloads.
- Wi-Fi only by default; optional user setting for cellular downloads. Respect changing connectivity as far as iOS background task APIs permit.
- A dedicated Downloads view shows queued, downloading, paused/failed, complete and deleted status; progress, storage requirement and free space checks.
- Downloads persist until manual deletion (do not automatically remove watched media).
- Offline playback works with radios disabled. On-device local player must support actual file container/codec; warn **before download** if compatibility is uncertain.
- Background transfers using Apple's documented background URLSession where possible; support retries/resume, unexpected logout/token refresh, app suspension, storage errors and user cancellation.
- Local metadata and per-profile credentials must not leak between users. Protect downloads with appropriate iOS file protection; do not imply DRM.
- Queue offline progress and watched/favourite events as needed; auto-sync once online.
- Conflict policy: **latest playback activity wins**; maintain stable timestamps/event IDs with deterministic tie breaking and explicit handling for device-clock ambiguity; avoid overwriting unrelated items. Document any limits.
- Opening an offline file must not require contacting Jellyfin at that moment.

## Settings and privacy

- Normal settings should be concise; Advanced includes playback engine preference (automatic default), stream diagnostics, transcoding policy, logs export and optional troubleshooting.
- Diagnostic report is on-device, exportable by user action, sanitized (remove tokens, credentials, hostname or identify redaction status, sensitive paths, private media titles by default). No automatic telemetry or external analytics.
- iOS local network permissions and Bonjour declarations are required for Cast discovery; sensible guidance if denied.
- App Store distribution and monetization are undecided. Avoid vendor-specific billing architecture until required.

## Non-goals for v1

Music, Live TV, EPG, Android app, watchOS, public social feeds, automatic intro detection, iPhone remote control of MahiFin tvOS app, cloud-hosted MahiFin accounts, mandatory third-party accounts, automatic video transcoding and automatic deletion of watched offline downloads.

## Design and accessibility

- Focus-based tvOS UI with obvious selection indicators and predictable back/menu behaviour.
- Support Siri Remote directional navigation and scrubbing using system conventions.
- Respect Dynamic Type / accessibility contrast and VoiceOver where feasible.
- UI uses system motion/reduce-motion preferences, stable image loading, graceful missing artwork.
- Distinguish streaming from downloaded and transcoding explicitly but unobtrusively.
