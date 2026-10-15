# Acceptance status — continued native implementation

Evidence is scoped: implemented means code exists and is wired; compile-tested means Apple compiler accepted it; fixture-tested means the named automated behavior ran successfully. Real-server evidence covers the exact synthetic matrix below; physical-device behavior remains pending. This is not the full v1 release.

## Verification evidence

- **Real-server integration passed at 70899c6**, [Linux run 38757601144](https://github.com/KasperMahi/MahiFin/actions/runs/38757601144): both Jellyfin **10.10.7 and 10.11.0**, eight Python tests (six ffmpeg-audit plus two real TLS proxy tests), production Swift client/probe and actual server ffmpeg. Reports contain actual server versions, image digests and allowlisted conversion evidence; no raw logs/authenticated URLs are artifacts.
- Both versions verified authentication/rejected password/independent users; real catalogs/search/paging/episodes; durable history, lost-response replay, favourites and profile isolation; session progress/stop and next-up; original SHA256/size/ranges/resume/cancellation. This is Linux integration evidence, not app UI or physical background execution.
- Actual HLS remux/audio-only output retained **3840×2160 H.264 video copy**, with copied AAC / converted FLAC-to-AAC and no video pixel processing. Explicit test-consented video encoded H.264 at at most 1920×1080, with bounded <=8 Mb/s maximum rate and finite VBV buffer. An active video ffmpeg process was cancelled and cleanup left zero ffmpeg processes. This small synthetic matrix is not a broad codec, visual-quality or HDR claim.
- **Apple passed at the same 70899c6**, [run 38757581425](https://github.com/KasperMahi/MahiFin/actions/runs/38757581425): **33 core tests, both unsigned simulator builds, 5 iOS + 3 tvOS UI tests**, Xcode 16.4 / Swift 6.1.2 / OS 18.5. Corrected mp4 container and 4K/1080p consent disclosure are included. Subsequent checkpoint edits change documentation only.
- Both platforms passed EN/DA onboarding, empty-credential guards and real VLCKit synthetic MKV enumeration/EOF. iOS additionally passed insecure-server rejection, embedded SRT off/select, reported seek position and production consent Cancel/Accept/new-attempt. Subtitle pixels, audible output, physical remote and broad codec coverage remain pending.
- Local eight Python tests, full synthetic-media generation/ffprobe, diagnostic sentinel redaction, syntax, repository target/localization and whitespace checks passed. No local Swift/Xcode or Linux Docker daemon.
- Earlier quota/startup/port/wizard/TLS/audit failures and repairs are historical in PROGRESS.md. No check was disabled; no billing change, real credential or media was used. SDK distribution/hardware gates remain open.

## Acceptance matrix

Apple compile/UI evidence and Linux server evidence are separate. Success applies to the named fixtures/paths only; physical output remains unverified.

| Continuation gate | Implemented | Compile / automated evidence | Real server / device status |
|---|---|---|---|
| I1/I2 Linux integration matrix, production Swift probe | Implemented | Eight Python tests + actual Swift probe passed | Both exact versions deployed/passed; Keychain/background/UI hardware pending |
| I3 HLS remux/audio/video, actual ffmpeg audit and DELETE cleanup | Implemented | Actual argv, fMP4 segments/ffprobe, 4K copy, AAC conversion, bounded video and active cleanup passed | H.264/AAC/FLAC synthetic fixtures only; wider codec/device matrix pending |
| I4 mp4 API contract fix / 4K quality disclosure | Implemented | Actual fMP4 HLS on both servers; both unsigned builds and consent UI passed at 70899c6 | Physical playback/quality/HDR remains pending |
| I5 Cast security investigation | Actionable receiver/auth/conversion strategy documented | Public source reviewed; no credential sent | Receiver owner patch/deployment and physical validation blocked |
| I6 Distribution preparation | Signing/Actions/ASC/TestFlight procedure and license review documented | No signed build, upload or Xcode 26 validation | Exact LGPL binary provenance/relinking, vendor terms/privacy and future credentials pending |

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
| PLAY-01 | Native/VLC seek/resume; setup/preroll guards; snapshots retained after sync | Yes | 720s snapshot/ack/restart/profile and preroll/early-stop tests; real iOS VLC seek position | Native interruption/device stop/restart; full Downloads UI |
| PLAY-02 | End callbacks, duplicate/stale generation guards, cancellable 5s next; no offline autoplay | Yes | Countdown + lifecycle ledger tests; real VLC EOF both platforms | Actual next-episode navigation/cancel/late-network UI races |
| PLAY-03 | Native + VLCKit original; copy/audio HLS; scoped expiring video consent | Yes | Fixtures/UI plus real 10.10.7/10.11.0 copy/audio/video ffmpeg output and cleanup passed | Broad codec/native-device HLS playback |
| PLAY-04 | Native H.264/AAC/AC3/EAC3 route | Yes | Metadata policy only | Synthetic playback/audio/seek |
| PLAY-05 | Width-constrained original H.264 route; never resolution downgrade | Yes | 3840 policy test | 4K profile/bitrate/performance |
| PLAY-06 | VideoToolbox HEVC and Apple HDR modes probe; Main10/HDR10/HLG only; no inferred DV or VLC HDR | Yes | Main10/mode/unknown-DV policy test | Physical 4K HDR output/HDMI chain pending |
| PLAY-07 | Official pinned VLCKit MKV original engine, pause/seek/audio/subtitle selection; bounded SDR policy | Yes | Real MKV H.264/AAC track enumeration/EOF both platforms; iOS seek + SRT selection | tvOS remote seek/selection; TrueHD/DTS/EAC3/HEVC/PGS/audio output matrix; LGPL gate |
| PLAY-08 | Native/VLC track menus; basic native None/OnlyForced/language preferences; external/image/Smart/alternative preferences incomplete | Yes | Embedded SRT off/select iOS; enumeration both platforms; no copy-path burn-in | Subtitle pixel rendering, preferences and external/image clips |
| PLAY-09 | Trusted server MediaSegments only, interval validation and skip seek | Yes | Trusted segment interval test | Server provider + UI seek |
| PLAY-10 | Finite HTTP timeouts, player failure category, diagnostics | Yes | HTTP failure mapping | Network loss/retry/failure notification |
| PLAY-11 | Native audio session; no passthrough claims | Yes | Not fixture-testable | Physical soundbar ARC/eARC gate |
| CAST-01 | Official iOS Cast SDK; authenticated configured ID/Bonjour validation, explicit discovery, real SDK connection state | Yes | Receiver-ID/privacy policy tests; no discovery hardware test | Local Network permission, stable/legacy receiver/reconnect |
| CAST-02 | SDK controls for existing media; per-command scoped resume/seek consent; Jellyfin load/reporting/lock screen blocked | Yes | No receiver/command-execution test | Real session controls/errors, lock screen/history |
| CAST-03 | Legacy capability consent policy; conversion execution unavailable | Yes | Legacy HEVC/4K -> consent-required policy | Real receiver acceptance/decline UI |
| CAST-04 | BLOCKED: audited receiver logs full accessToken envelope and may automatically convert; sender never sends it | Yes boundary | Credential-envelope guard test; upstream source audit | Redact receiver logs and verify no implicit encoding before auth/load can be enabled |
| AIR-01 | iOS AVRoutePickerView + native external playback/audio session | Yes | No route test | AirPlay physical playback/seek/background |
| OFF-01 | Background original transfer, Wi-Fi/cellular, manifest/free-space/progress; probed original-size verification | Yes | Original endpoint + truncated/full/206 range fixtures | Device bytes/hash/background/cellular |
| OFF-02 | Local native/VLC original without server lookup; snapshots retain resume; online preference cannot force offline remux | Yes | Path/account/ack/restart tests; real local MKV both platforms | Airplane mode before navigation; full Downloads UI/history integration |
| OFF-03 | Files retained, explicit deletion, resume-data cleanup | Yes | Manifest model only | Relaunch/watch/delete disk verification |
| OFF-04 | Owner-filtered view/path lookup; logout pauses transfer | Yes | Account isolation queue/path tests | B cannot access A transfer/assets |
| OFF-05 | Atomic queue/snapshots, absolute partial updates, conflict retention without blocking other items; no cross-client CAS | Yes | Lost-response, selective conflict, newer-server cache/newer-local protection tests | Reconnect/retry/two devices/skew |
| OFF-06 | Restore task mapping, pause/resume/retry/failure and storage categories; force-quit follows OS | Yes | Actual URLSession delegate tests pending | Kill/lock/low-space/401/partial file |
| DIAG-01 | Structured allowlist excludes URLs/titles/tokens/paths; export on iOS, display tvOS | Yes | Malicious diagnostic input test | Share/export and player-category review |
| CI-01 | Deterministic checked-in two-target project, pinned unsigned macOS build | Yes | Both builds passed run linked above | No physical signing required |
| CI-02 | Core fixtures, onboarding, real MKV/consent XCUITest; real Linux matrix and source provenance | Yes | 33 core + 5 iOS + 3 tvOS tests, plus both real-server jobs/8 Python tests passed at 70899c6 | Broader codec/UI matrix; exact SDK distribution materials |

## Remaining prioritized work

1. **Cast external blocker:** the audited receiver source logs full credential envelopes and independently negotiates conversion; the actual deployed revision is unverified. Keep Jellyfin auth/media load disabled until receiver redaction, authorization strategy and per-load/track/seek no-implicit-video contract are verified on the deployed revision. Then finish load/history/lock-screen/reconnect and legacy receiver tests.
2. **Broader server gate:** the 10.10.7/10.11.0 synthetic matrix passes; expand codec/settings/Quick Connect coverage and test any additional deployable version separately. No Jellyfin 12 claim. Preserve actual command/output/cancellation assertions; pin reported image digests when changing the deployment matrix.
3. **Hardware gate:** signed iPhone/Apple TV playback, native resume interruptions, 4K/HDR output, audio/ARC, AirPlay, background downloads, force-quit/lock/storage/401, airplane-mode replay and history across devices. No physical behavior was verified here.
4. **Remaining implementation/tests:** external/image subtitles and full Smart/default/alternative-engine preferences; broader codec/audio matrix; catalog/download/auto-next lifecycle UI fixtures; dedicated seasons/backdrops, focus and accessibility polish.
5. **Distribution gate:** preserve exact VLCKit/libVLC/contrib corresponding sources/build notices and LGPL replacement/relinking materials; review Google binary terms/privacy. Retained license text is not a complete binary-distribution audit.

All 33 acceptance IDs remain accounted for. Compile-tested means the current source builds, not that a complete acceptance row or hardware behavior passed. Earlier failed runs and repairs are retained in PROGRESS.md; do not repeat completed adapters/audits on resume.

Exact steps: [MANUAL_TESTS.md](MANUAL_TESTS.md). Build/reproduction commands: README. Resume: PROGRESS.md and Git history. Draft PR #1 remains unmerged.
