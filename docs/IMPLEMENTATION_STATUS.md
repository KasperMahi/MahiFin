# Acceptance status — continued native implementation

Evidence is scoped: implemented means code exists and is wired; compile-tested means Apple compiler accepted it; fixture-tested means the named automated behavior ran successfully. Hardware/live-server behavior is pending throughout. This is not the full v1 release.

## Verification evidence

- Initial baseline: Xcode 16.4 / Swift 6.1.2 on GitHub macOS 15, [run 38620804616](https://github.com/KasperMahi/MahiFin/actions/runs/38620804616), **17 core tests**, both unsigned builds, **3 iOS and 2 tvOS onboarding UI tests** at `97faa54`. New continuation evidence is listed separately below.
- Windows Python structural checks passed: deterministic project, target minimums, fixture parsing, localization key parity. No Swift/Xcode installed locally.
- OS 18 simulator runtimes available. Onboarding EN/DA, empty-credential guards (both platforms), and insecure-server rejection (iOS) passed. Catalog/download UI, broader player lifecycle and real server/account/media/hardware remain pending.
- Continuation [run 38627898488](https://github.com/KasperMahi/MahiFin/actions/runs/38627898488) at `6b906ed`: **24 core tests, both unsigned builds and 4 iOS UI tests passed**, including real synthetic H.264/AAC MKV playback/seek/EOF via VLCKit. Overall run failed before tvOS UI tests (FrontBoard could not find runner). Latest R5 edits and track-count assertions still require rerun.
- Pinned official VLCKit and iOS-only Google Cast SDK; notices/source-distribution gates in THIRD_PARTY_NOTICES.md. Media is generated from authored color/audio/subtitle fixtures in CI, with no private content.
- R5 [run 38630429136](https://github.com/KasperMahi/MahiFin/actions/runs/38630429136) at `f0da22f`: **31 core tests and both unsigned builds passed**. New iOS embedded-track enumeration assertion failed; tvOS UI skipped after that failure. This is not a green CI run or track verification. Explicit fixture start/longer clip/detailed failure output are in the next rerun, alongside the consent UI and selected-audio tests.
- [Run 38632768362](https://github.com/KasperMahi/MahiFin/actions/runs/38632768362) at `f103d67`: **32 core tests, both unsigned builds and iOS explicit consent UI passed**. MKV reported 1 audio / 2 subtitles because the bundled SRT muxing input was auto-discovered alongside the embedded track. Fixture input isolation repaired for next run; selection/seek assertions still pending and overall run failed. tvOS not executed in this run.

## Acceptance matrix

| ID | Implemented / limitations | Compile-tested | Fixture-tested evidence | Hardware / next step |
|---|---|---|---|---|
| AUTH-01 | Quick Connect enabled/initiate/poll/auth, cancel and 2-minute timeout | Yes | Endpoint sequence/auth response + transport cancellation; denial/timeout integration pending | Live success/denial/timeout; MANUAL_TESTS setup |
| AUTH-02 | Password auth and Keychain token persistence | Yes | Password JSON, HTTP errors | Restart/keychain/integration smoke |
| AUTH-03 | tvOS cold-launch chooser; independent account clients and keyed data | Yes | ProfilePolicy + queue isolation | Physical remote + foreground test |
| AUTH-04 | iOS remembered profile; view identity reset on switch | Yes | ProfilePolicy | UI switch/relaunch |
| UI-01 | Home three rows, poster grids, missing art, loading/empty/error | Yes | Catalog JSON/resume request | UI snapshot/live library |
| UI-02 | Genre/year/unwatched/library/sort, paging, debounced search | Yes | Filter and pagination request assertions pass; UI dedup/search still pending | Multi-library >60-item validation |
| UI-03 | Details/rating/cast, ordered episode list, watched/favourite mutations; dedicated season navigation/backdrop not yet built | Yes | Independent watched/favourite request assertions pass | API + UI acceptance |
| UI-04 | EN/DA key parity and localized error/accessibility basics | Yes | Structural parity + native EN/DA onboarding UI tests pass | Full app VoiceOver/dynamic type/locales |
| PLAY-01 | Native/VLC seek/resume; per-account queue plus snapshots retained after sync | Yes, f0da22f | 720s snapshot/ack/restart/profile isolation; real iOS MKV baseline | Device stop/restart/seek; full Downloads UI |
| PLAY-02 | End callbacks, duplicate/stale generation guards, cancellable 5s next; no offline autoplay | Yes, f0da22f | Countdown + lifecycle ledger tests; iOS real EOF baseline | Actual next-episode navigation/cancel/late-network UI races |
| PLAY-03 | Native + pinned VLCKit original; remux/audio copy paths; per-source expiring consent before video encoding | Yes, 6b906ed | Copy request/consent scope tests; real iOS MKV seek/EOF | Live server ffmpeg copy/encoding/cleanup audit; tvOS runtime rerun |
| PLAY-04 | Native H.264/AAC/AC3/EAC3 route | Yes | Metadata policy only | Synthetic playback/audio/seek |
| PLAY-05 | Width-constrained original H.264 route; never resolution downgrade | Yes | 3840 policy test | 4K profile/bitrate/performance |
| PLAY-06 | VideoToolbox HEVC and Apple HDR modes probe; Main10/HDR10/HLG only; no inferred DV or VLC HDR | Yes, 6b906ed | Main10/mode/unknown-DV policy test | Physical 4K HDR output/HDMI chain pending |
| PLAY-07 | Real official VLCKit MKV original engine, pause/seek/audio/subtitle selection; bounded SDR policy | Yes, 6b906ed | iOS synthetic MKV H.264/AAC seek/EOF passed; track assertions pending | tvOS runtime; TrueHD/DTS/EAC3/HEVC/PGS/audio output matrix; LGPL distribution gate |
| PLAY-08 | Native and VLC track menus; basic native None/OnlyForced/language preferences; external/image/Smart preferences incomplete | Yes, 6b906ed | Burn-in blocked from copy conversion; embedded SRT enumeration test pending | Track selection/rendering and preference clips |
| PLAY-09 | Trusted server MediaSegments only, interval validation and skip seek | Yes | Trusted segment interval test | Server provider + UI seek |
| PLAY-10 | Finite HTTP timeouts, player failure category, diagnostics | Yes | HTTP failure mapping | Network loss/retry/failure notification |
| PLAY-11 | Native audio session; no passthrough claims | Yes | Not fixture-testable | Physical soundbar ARC/eARC gate |
| CAST-01 | Official iOS Cast SDK; authenticated configured ID/Bonjour validation, explicit discovery, real SDK connection state | Yes, 6b906ed | Receiver-ID/privacy policy tests; no discovery hardware test | Local Network permission, stable/legacy receiver/reconnect |
| CAST-02 | Actual SDK controls for existing media; resume/seek consent gate pending compile; Jellyfin load/reporting/lock screen blocked | Yes SDK; latest gate pending | No receiver test | Receiver session controls/errors, lock screen/history |
| CAST-03 | Legacy capability consent policy; conversion execution unavailable | Yes | Legacy HEVC/4K -> consent-required policy | Real receiver acceptance/decline UI |
| CAST-04 | BLOCKED: audited receiver logs full accessToken envelope and may automatically convert; sender never sends it | Yes, 6b906ed | Credential-envelope guard test; upstream source audit | Redact receiver logs and verify no implicit encoding before auth/load can be enabled |
| AIR-01 | iOS AVRoutePickerView + native external playback/audio session | Yes | No route test | AirPlay physical playback/seek/background |
| OFF-01 | Background original transfer, Wi-Fi/cellular, manifest/free-space/progress; probed original-size verification | Yes, f0da22f | Original endpoint + truncated/full/206 range fixtures | Device bytes/hash/background/cellular |
| OFF-02 | Downloads opens local native/VLC original without server lookup; synced snapshots retain resume | Yes, f0da22f; latest preference fix pending | Path/account/ack/restart tests; synthetic local MKV engine baseline | Airplane mode before navigation; full UI/history integration |
| OFF-03 | Files retained, explicit deletion, resume-data cleanup | Yes | Manifest model only | Relaunch/watch/delete disk verification |
| OFF-04 | Owner-filtered view/path lookup; logout pauses transfer | Yes | Account isolation queue/path tests | B cannot access A transfer/assets |
| OFF-05 | Atomic queue/snapshots, absolute partial updates, conflict retention without blocking other items; no cross-client CAS | Yes, f0da22f | Lost-response, selective conflict, newer-server cache/newer-local protection tests | Reconnect/retry/two devices/skew |
| OFF-06 | Restore task mapping, pause/resume/retry/failure and storage categories; force-quit follows OS | Yes | Actual URLSession delegate tests pending | Kill/lock/low-space/401/partial file |
| DIAG-01 | Structured allowlist excludes URLs/titles/tokens/paths; export on iOS, display tvOS | Yes | Malicious diagnostic input test | Share/export and player-category review |
| CI-01 | Deterministic checked-in two-target project, pinned unsigned macOS build | Yes | Both builds passed run linked above | No physical signing required |
| CI-02 | Core fixtures, onboarding, real MKV and consent XCUITest; source provenance and retained xcresults | Yes at recorded commits; latest test edits pending | 31 core passed f0da22f; onboarding/limited MKV evidence above; track rerun pending | Full runtime gate and exact SDK distribution materials |

## Remaining prioritized work

Continuation R0 review: completed local replay starts at zero; download integrity requires probed original size and rejects a truncated HTTP length. Regression tests authored; fresh CI pending. Orphan background tasks are cancelled during reconciliation. Alternative engine audit is in progress; no new compatibility claim yet.

R0 core tests + both unsigned builds passed run 38625217485 at 2b54fb8. R1: official pinned VLCKit adapter, original streaming/offline MKV, seek/audio/subtitle controls and synthetic MKV integration harness are implemented but NOT compile/runtime tested yet. Existing matrix's earlier evidence remains historical until the R1 run. LGPL distribution follow-up is recorded in THIRD_PARTY_NOTICES.md; no physical codec/audio/HDR claims.

R1 first compiler run resolved binary and built Obj-C, then failed Swift imported method spelling; explicit naming repair pending rerun. R2 remux/audio-only native HLS execution uses VideoCodec=copy, no sizing/burn-in; scoped consent UI required before h264 encoding. R3 probes actual Apple HDR modes/hardware decoding; known HEVC Main10 HDR10/HLG routes only, Dolby Vision remains blocked. These additions are implemented/test-authored but compile/live/hardware evidence is pending.

Iteration 2 passed 22 core tests, then failed app access to synthesized internal decision initializer (repaired). R4 official Cast SDK discovery/configured-ID/session controls are implemented but compiler/hardware evidence pending. Authentication/media load remains BLOCKED by confirmed receiver token logging and automatic conversion negotiation, rather than a guessed ID. No token envelope is transmitted. See new decision record for exact source/exit tests.

Current pending R5 follow-up: atomic queue/resume snapshot persistence, selective conflict sync, late/duplicate playback ledger, original-size HTTP 206 validation, current title/seek accessibility, and source-scoped existing-Cast control consent. A separate follow-up adds shared production consent-dialog UI tests, unique request identity, offline engine selection independent of online preference, and selected/default-audio-only routing to avoid converting unused tracks. These are implemented/test-authored; CI evidence will be recorded after execution.

1. Finish latest CI and record exact core/iOS/tvOS runtime results; expand catalog/download lifecycle and track-rendering UI tests.
2. Live API fixtures/integration across 10.10/10.11/12, metadata/permissions/Quick Connect/media profiles.
3. Real native-compatible playback/offline/AirPlay acceptance on iPhone and Apple TV; trusted subtitle/marker behavior.
4. Validate implemented alternative/copy/audio/video routes with the larger synthetic codec matrix and live ffmpeg audit; finish external subtitles/full preferences and distribution materials.
5. Fix/validate deployed receiver credential logging and implicit conversion, then enable Jellyfin Cast authorization/load/history and legacy receiver hardware tests.
6. HDR/device capability, advanced subtitles, season/backdrop presentation, focus/accessibility polish.

Exact steps: [MANUAL_TESTS.md](MANUAL_TESTS.md). Reproduction commands: README. Resume work: PROGRESS.md + Git history. No unchecked acceptance row is claimed complete.
