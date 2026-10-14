# Acceptance status — initial native implementation

Evidence is scoped: implemented means code exists and is wired; compile-tested means Apple compiler accepted it; fixture-tested means the named automated behavior ran successfully. Hardware/live-server behavior is pending throughout. This is not the full v1 release.

## Verification evidence

- Xcode 16.4 / Swift 6.1.2 on GitHub macOS 15. [Run 38617972775](https://github.com/KasperMahi/MahiFin/actions/runs/38617972775) passed package tests and both unsigned simulator builds at commit `475548a` (12 tests). Later hardening/tests require final rerun.
- Windows Python structural checks passed: deterministic project, target minimums, fixture parsing, localization key parity. No Swift/Xcode installed locally.
- Simulator runtimes are available. No UI smoke tests have run yet. No real server/account/media/hardware supplied.
- No runtime third-party packages; provenance in THIRD_PARTY_NOTICES.md. All test metadata is invented, no media binaries.

## Acceptance matrix

| ID | Implemented / limitations | Compile-tested | Fixture-tested evidence | Hardware / next step |
|---|---|---|---|---|
| AUTH-01 | Quick Connect enabled/initiate/poll/auth, cancel and 2-minute timeout | Yes | API request coverage incomplete | Live success/denial/timeout; MANUAL_TESTS setup |
| AUTH-02 | Password auth and Keychain token persistence | Yes | Password JSON, HTTP errors | Restart/keychain/integration smoke |
| AUTH-03 | tvOS cold-launch chooser; independent account clients and keyed data | Yes | ProfilePolicy + queue isolation | Physical remote + foreground test |
| AUTH-04 | iOS remembered profile; view identity reset on switch | Yes | ProfilePolicy | UI switch/relaunch |
| UI-01 | Home three rows, poster grids, missing art, loading/empty/error | Yes | Catalog JSON/resume request | UI snapshot/live library |
| UI-02 | Genre/year/unwatched/library/sort, paging, debounced search | Yes | Paging/filter assertions pending | Multi-library >60-item validation |
| UI-03 | Details/rating/cast, ordered episode list, watched/favourite mutations; dedicated season navigation/backdrop not yet built | Yes | Mutation request coverage pending | API + UI acceptance |
| UI-04 | EN/DA key parity and localized error/accessibility basics | Yes | Structural parity only | VoiceOver/dynamic type/locales |
| PLAY-01 | Native seek/resume; per-account durable queue and server progress | Yes | 720s fixture + durable queue | Device stop/restart/seek |
| PLAY-02 | End notification, stop once, 5s cancellable next; no offline autoplay | Yes | Countdown pure function; lifecycle integration pending | End/Cancel/navigation race tests |
| PLAY-03 | Conservative route policy; native execution; alternative/remux/audio/video execution BLOCKED | Yes | Policy matrix + original URLs | Integrate actual supported adapter/conversion contracts |
| PLAY-04 | Native H.264/AAC/AC3/EAC3 route | Yes | Metadata policy only | Synthetic playback/audio/seek |
| PLAY-05 | Width-constrained original H.264 route; never resolution downgrade | Yes | 3840 policy test | 4K profile/bitrate/performance |
| PLAY-06 | HDR route conservatively rejected (no verified display capability) | Yes | No HDR output test | BLOCKED hardware capability and HDR10 output gate |
| PLAY-07 | Unsupported MKV/audio surfaces error; local alternative engine BLOCKED | Yes | MKV/TrueHD policy | License/pin actual engine, audio matrix |
| PLAY-08 | Native track menus, basic None/OnlyForced/language preferences; external/image/Smart selection incomplete | Yes | Burn-in never starts conversion | Track preference/subtitle clips |
| PLAY-09 | Trusted server MediaSegments only, interval validation and skip seek | Yes | Trusted segment interval test | Server provider + UI seek |
| PLAY-10 | Finite HTTP timeouts, player failure category, diagnostics | Yes | HTTP failure mapping | Network loss/retry/failure notification |
| PLAY-11 | Native audio session; no passthrough claims | Yes | Not fixture-testable | Physical soundbar ARC/eARC gate |
| CAST-01 | BLOCKED official SDK/receiver integration. Explicit unavailable settings; no false connected state | Protocol compiles | No discovery test | Verify ID/protocol/auth then integrate SDK |
| CAST-02 | BLOCKED actual remote controls/reconnect/lock screen | Protocol compiles | No receiver test | Real legacy receiver + reporting |
| CAST-03 | Legacy capability consent policy; conversion execution unavailable | Yes | Legacy HEVC/4K -> consent-required policy | Real receiver acceptance/decline UI |
| CAST-04 | BLOCKED secure receiver authentication contract; no token sent to receiver | Boundary compiles | No receiver test | Supported secure receiver protocol |
| AIR-01 | iOS AVRoutePickerView + native external playback/audio session | Yes | No route test | AirPlay physical playback/seek/background |
| OFF-01 | Background authenticated original transfer, Wi-Fi default/cellular, manifest/free-space/progress | Yes | Original endpoint construction only | Device bytes/hash/background/cellular |
| OFF-02 | Download view opens local AVURLAsset without Jellyfin lookup; local queue resume | Yes | Local manifest account/path validation; full playback pending | Airplane mode before navigation |
| OFF-03 | Files retained, explicit deletion, resume-data cleanup | Yes | Manifest model only | Relaunch/watch/delete disk verification |
| OFF-04 | Owner-filtered view/path lookup; logout pauses transfer | Yes | Account isolation queue/path tests | B cannot access A transfer/assets |
| OFF-05 | Deterministic item/account queue, absolute partial updates, clock conflict retention; no cross-client atomic CAS | Yes | Queue/conflict tests; full sync tests added pending rerun | Reconnect/retry/two devices/skew |
| OFF-06 | Restore task mapping, pause/resume/retry/failure and storage categories; force-quit follows OS | Yes | Actual URLSession delegate tests pending | Kill/lock/low-space/401/partial file |
| DIAG-01 | Structured allowlist excludes URLs/titles/tokens/paths; export on iOS, display tvOS | Yes | Malicious diagnostic input test | Share/export and player-category review |
| CI-01 | Deterministic checked-in two-target project, pinned unsigned macOS build | Yes | Both builds passed run linked above | No physical signing required |
| CI-02 | Core XCTest fixtures and source provenance | Yes | 12 tests passed; latest additions pending rerun | License audit on future SDK additions |

## Remaining prioritized work

1. Finish final compiler/test iteration and playback/offline race review; add simulator UI smoke coverage.
2. Live API fixtures/integration across 10.10/10.11/12, metadata/permissions/Quick Connect/media profiles.
3. Real native-compatible playback/offline/AirPlay acceptance on iPhone and Apple TV; trusted subtitle/marker behavior.
4. Integrate licensed alternative engine/remux/audio conversion with exact no-video-copy safeguards; explicit per-attempt video consent before any conversion request.
5. Verified Google Cast sender/receiver lifecycle and secure auth, then legacy receiver hardware gate.
6. HDR/device capability, advanced subtitles, season/backdrop presentation, focus/accessibility polish.

Exact steps: [MANUAL_TESTS.md](MANUAL_TESTS.md). Reproduction commands: README. Resume work: PROGRESS.md + Git history. No unchecked acceptance row is claimed complete.
