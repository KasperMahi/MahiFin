# MahiFin implementation progress

Resume from this checklist and Git history. Never equate implemented with tested.

## Prioritized milestones

- [x] Read task, product, architecture, acceptance and research documents; inspect clean starter repository.
- [x] A: Audit dependencies and API contracts; record decisions and verification constraints.
- [x] B1: Shared Swift package, real Jellyfin HTTP client, secure accounts, fixture tests (execution pending CI).
- [x] B2: Native iOS/tvOS project, onboarding, profiles, catalog, search and details (compile verification pending).
- [x] B3: Original-only AVPlayer, durable progress and cancellable next episode wired (compile/hardware verification pending; conversion integrations blocked).
- [x] B4: iPhone background original download and offline playback/history wiring, AirPlay; honest Cast/alternative-engine boundaries (compile/device verification pending).
- [x] C: Pinned macOS CI; compile both targets and run tests; repair failures (passed at 475548a; final hardening rerun pending).
- [ ] D: Acceptance status matrix, reproducible setup/manual tests, private-repository PR.

## Verification and blockers

- Initial working tree clean; base commit `41fc73c`.
- Host is Windows. No Swift/Xcode executable found; Apple compilation requires macOS CI.
- No real server, credentials, receiver ID, media, or hardware supplied; use invented JSON fixtures only.
- GitHub access/privacy and CI availability still to verify. Do not change visibility or purchase quota.

## Milestone results

Planning: required documents read; no code tests exist yet. This file created before implementation.

Audit: private repository/push permissions verified. Reviewed upstream sources and macOS runner manifest; choose Xcode 16.4 on macOS 15. No runtime dependency copied. API fixtures/tests are next; no Swift execution available locally.

B1: Added core request boundary/models, HTTPS and redirect restrictions, profile policy, durable history, download manifest, conservative playback policy and diagnostic allowlist. Ten meaningful XCTest cases with invented fixture metadata are authored. Tests NOT executed on Windows; Apple compiler/CI remains pending. Native app wiring is in progress and included in this working snapshot as requested; it does not yet have a generated project.

B2–B4 implementation snapshot: generated real Xcode targets/schemes (iOS/tvOS 18), localized EN/DA screens, password/Quick Connect, Keychain profiles, real catalog/search/details, original-only native playback, progress/next episode, iPhone background downloader and local-file route. Local Python structural checks passed (project, deployment targets, fixture JSON, translation parity). Swift tests and Apple builds NOT executed yet. Cast, alternative engine, server conversion and trusted markers are tracked gaps. Next: push draft PR, inspect macOS CI and repair compiler/runtime correctness issues.

CI iteration 1: run 38617202620 reached Xcode 16.4/Swift 6.1.2; reproducibility checks passed. Swift package manifest failed because `.v18` requires PackageDescription 6.0. Changed to explicit `18.0` version strings while retaining Swift 5 language mode. App builds were skipped; no passed Swift tests yet. Draft PR #1 is open in private repository.

CI iteration 2: run 38617389993 failed on Swift reserved `Type` member names and optional collection `first` syntax. Escaped JSON `Type` properties and made diagnostic lookup explicit. Also changed storage initialization from fatal crash to retry screen and fixed next-episode task self-cancellation. API audit confirmed nullable partial UpdateUserItemDataDto (10.10.7); position writes do not clear favourites. Next: rerun compiler/tests and inspect both app builds.

CI iteration 3: run 38617580188 passed all 10 core tests, then iOS compilation exposed initialization-order error (account property accessed before download manager initialization). Reordered initialization. Added original-request update tests and validated trusted MediaSegments API from upstream 10.10.7; wired marker skips and basic native subtitle/audio preferences. Twelve tests now authored; new changes need rerun. Background cleanup races repaired; original downloads require one unambiguous media source. Conversion and Cast still blocked.

CI iteration 4: run 38617972775 succeeded at 475548a: 12 tests, iOS unsigned simulator build, tvOS unsigned simulator build, reproducibility and localization checks. No UI/hardware tests. Added shared HistorySync with lost-response/idempotent replay fixtures, serialized Progress/Stopped network events, persisted cellular preference and newest local-event resume. README, acceptance matrix and exact hardware repro steps authored. Local structural checks still pass. Next: final Swift/build rerun and simulator smoke coverage; release blockers remain explicit.

Simulator smoke milestone: added genuine XCUITest targets/scheme test actions for both platforms, EN/DA onboarding checks and iOS insecure-URL rejection through the actual UI. These have not run yet. CI selects an available simulator and fails explicitly if no runtime exists. Project regeneration + structural checks passed locally. Never treat these limited onboarding tests as catalog/playback/device validation.

CI iteration 5: run 38618971250 passed all 14 core tests and both app builds, but UI smoke selected OS 26 with Xcode 16.4 and failed linking arm64/x86_64 products before launch. Fixed runner to choose OS 18 (prefer 18.5), match host architecture and use separate smoke DerivedData. No UI assertion has passed yet. Audit also found Jellyfin's Static=true disc-source exception; policy/URL construction now require explicit VideoFile, with rejection tests. Added native mid-stream failure notification and offline-end stop cleanup. Final rerun required.

Final correctness review: added cancellation generation guards and serialized initial Playing events, so late old callbacks cannot affect a replacement session. Download resume blobs (may contain auth headers) now live in device-only Keychain; obsolete task callbacks are ignored. Added Quick Connect sequence, auth cancellation, filter/paging and independent mutation contract tests (17 total authored). Local structural checks pass. Run 38619487238 has passed 14 tests and both builds and is executing limited onboarding UI smoke; these latest changes still require a new run. Cast/alternative/conversion/hardware gates remain unfinished.

Playback review follow-up: detach a stopped player before awaiting network work; guard overlapping open operations; invalidate completion lookups on navigation/stop so they cannot start hidden autoplay. `git diff --check` passes. No secrets/real service addresses found in application source; only documented token construction in request headers/in-memory AVPlayer URL. Awaiting smoke result before pushing this final snapshot to avoid cancelling useful UI validation.

CI iteration 6: run 38619487238 succeeded at f0428f7: all 14 core tests, both unsigned builds and genuine iOS/tvOS onboarding XCUITest passed. Both OS 18 runtimes are present. Security/lifecycle/API-contract additions after that commit are ready for final rerun (17 core tests authored). Diagnostics now include allowlisted reason/HDR and bounded numeric bitrate/width without private metadata. Final push next; no later code edits planned unless validation exposes a failure.
