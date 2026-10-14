# MahiFin implementation progress

Resume from this checklist and Git history. Never equate implemented with tested.

## Prioritized milestones

- [x] Read task, product, architecture, acceptance and research documents; inspect clean starter repository.
- [x] A: Audit dependencies and API contracts; record decisions and verification constraints.
- [x] B1: Shared Swift package, real Jellyfin HTTP client, secure accounts, fixture tests (execution pending CI).
- [x] B2: Native iOS/tvOS project, onboarding, profiles, catalog, search and details (compile verification pending).
- [x] B3: Original-only AVPlayer, durable progress and cancellable next episode wired (compile/hardware verification pending; conversion integrations blocked).
- [x] B4: iPhone background original download and offline playback/history wiring, AirPlay; honest Cast/alternative-engine boundaries (compile/device verification pending).
- [ ] C: Pinned macOS CI; compile both targets and run tests; repair failures.
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
