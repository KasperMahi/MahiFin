# Codex working agreement — MahiFin

Read `docs/PRODUCT_SPEC.md`, `docs/TECHNICAL_ARCHITECTURE.md`, and `docs/ACCEPTANCE_TESTS.md` before editing code. The user's product decisions are fixed. If one requirement conflicts with platform restrictions, document the issue and implement the safest useful fallback instead of silently deviating.

## Non-negotiables

- Keep repository private; do not add live Jellyfin server URL, real credentials, real media, private metadata or key material.
- Target **iOS 18+ and tvOS 18+**. Don't import current Swiftfin code that requires tvOS 26 without safe compatibility adaptation.
- Build a real native Swift/SwiftUI app with iOS and tvOS targets and shared reusable modules, not a static mock or HTML wrapper.
- Implement all reasonable layers end-to-end, including wired navigation, state, persistence and tests. If something requires real hardware, put it behind an honest interface, implement everything testable, and record exact follow-up steps.
- Never request or allow **video transcoding** without explicit human acceptance in UI. Auto-convert audio only when needed. Direct Play preferred, local alternative engine and remux before server video conversion.
- Support HDR and codecs carefully; no blanket guarantees about MKV/TrueHD/Dolby Vision, audio passthrough or Google Cast receiver compatibility without tests.
- Preserve player position/watched status per account, idempotently and accurately. Handle app lifecycle and retries.
- Background iPhone original downloads, offline playback and deterministic sync are first-version scope, NOT postponed as out-of-scope.
- Do not fake success, mark unimplemented modules complete, disable failing tests, or invent API methods; compile against actual packages/docs.
- Third-party licenses: retain MPL 2.0 notices and provide distribution of covered source files as needed, track dependencies and licenses.
- Log no secrets. Store auth tokens in Keychain. Sanitize exported diagnostics.

## Execution

1. Conduct a fast architecture/dependency audit; write concise findings to `docs/IMPLEMENTATION_DECISIONS.md`.
2. Implement one coherent project with both targets, shared infrastructure, UI, playback and mobile-only modules. Use real Jellyfin API integration plus fixture-powered tests.
3. Create CI workflow for unsigned iOS/tvOS simulator builds and unit tests; pin an available Xcode version. If the runner has no simulator, explain separately.
4. Build/test repeatedly and fix compile errors. Report tested vs untested instead of claiming hardware behaviour from simulator success.
5. Leave `docs/IMPLEMENTATION_STATUS.md` with an item-by-item matrix: implemented, compile-tested, fixture-tested, hardware-pending, blocked; include exact repro/next steps.
6. Open a pull request with the implementation, CI result, decisions, risks and manual test procedure; if GitHub PR permissions unavailable, deliver branch/patch plus commands.

## Quality bar

- No placeholder primary screens masquerading as finished features, no nonfunctional buttons. A real functional vertical slice is better than a broad clickable fake.
- Prefer Swift concurrency + protocol abstraction, explicit error types, cancellation and retry; avoid unnecessary frameworks.
- tvOS focus navigation, remote seeking; dynamic localized UI; iOS Cast/Downloads only in mobile target.
- Use only legally shareable media test fixtures. No external service added without reason and privacy review.
