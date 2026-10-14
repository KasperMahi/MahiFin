# MahiFin

**Status:** specification and Codex implementation starter, 14 October 2026. **No production app has been implemented or validated yet.**

MahiFin is a proposed native Jellyfin client for iOS and tvOS. Product focus: Netflix-inspired but straightforward, reliable 4K/HDR playback, Jellyfin-backed progress, profiles, Google Cast + AirPlay on iOS, and original-file offline downloads.

## Start here

1. Create a **private** GitHub repository named `MahiFin`; do not commit API tokens, server addresses, or personal media.
2. Copy the *contents* of this directory to the repository and commit them.
3. In Codex, open the GitHub repository and paste `CODEX_TASK.md` as the primary instruction. Codex must read `AGENTS.md`, `docs/PRODUCT_SPEC.md`, `docs/TECHNICAL_ARCHITECTURE.md`, and `docs/ACCEPTANCE_TESTS.md`.
4. Ask Codex to implement in a feature branch and open a PR. It should run and repair builds/tests as far as its execution environment allows and explicitly record what it could not verify.
5. Run macOS GitHub Actions builds **without code signing** first. Hardware testing, App Store Connect and TestFlight come later, after the relevant paid membership is obtained.

## Scope

- iOS 18+ and tvOS 18+
- Films and TV series, profiles, search, progress, favourite/watched flags, skip intro/credits if server provides markers
- Playback policy: Direct Play -> local player fallback or remux -> audio-only transcode if needed -> video transcode **only with explicit permission**
- iPhone: Cast + AirPlay; original-quality offline downloads
- Danish and English UI; no tracking by default

## Documents

- `docs/PRODUCT_SPEC.md`: complete requirements and design decisions
- `docs/TECHNICAL_ARCHITECTURE.md`: constraints, reuse decision, player/cast/offline design, security and licensing
- `docs/ACCEPTANCE_TESTS.md`: test matrix, release gates and known untestable-on-CI features
- `CODEX_TASK.md`: self-contained one-shot coding assignment
- `AGENTS.md`: standing Codex development rules
- `docs/RESEARCH_LINKS.md`: reference links and validation points

Do not interpret a successful simulator build as proof of real hardware performance, HDR output, ARC audio synchronization, Cast receiver compatibility or App Store approval.
