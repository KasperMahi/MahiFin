# One-shot Codex task: implement MahiFin

You are implementing the first integrated version of **MahiFin**, a native iOS/tvOS Jellyfin media app. This is a **large implementation assignment**, not a request for suggestions or planning only. Start from this repo's documents and build as much as possible in one run, using autonomous iteration and macOS CI where available. **Do not claim hardware-only features have been verified if you could not test actual hardware.**

## Required reading (in order)

1. `AGENTS.md`
2. `docs/PRODUCT_SPEC.md`
3. `docs/TECHNICAL_ARCHITECTURE.md`
4. `docs/ACCEPTANCE_TESTS.md`
5. `docs/RESEARCH_LINKS.md`

Treat these as acceptance contract. Do not ask the user basic product questions already answered here. When a technical detail remains unknown (server version, receiver app ID, real media profiles), use an architecture that discovers/probes it and document follow-up, rather than fabricating an answer.

## Deliverable

A genuine **buildable Xcode multi-target project** for iOS 18+ / tvOS 18+ with shared packages, a polished Netflix-inspired-but-original UI, Jellyfin server onboarding (Quick Connect + password), profile management, home/library/search/details, accurate Jellyfin watched/progress/resume/next episode, playback decision engine and at least working local AVPlayer path, isolated alternative playback path where feasible, Chromecast iOS integration, AirPlay, original-file offline download + playback + progress sync. DA/EN localization, settings and sanitized diagnostics, tests and GitHub Actions builds.

## Do these phases during the SAME implementation assignment

**Phase A — audit/research:** Check Swiftfin current vs older targets and license (tvOS 26 mismatch), jellyfin-sdk-swift version vs server compatibility, AVPlayer vs alternative player APIs, Cast sender/receiver protocol and app ID, URLSession background original download constraints, licensing. Write findings and choose reuse method; prefer minimal dependencies but avoid reinvention.

**Phase B — implementation:** Build a real project, no fake API, no dummy-only primary routes. Establish protocol-based clients for Jellyfin, playback, Chromecast, downloads, clocks, persistence and diagnostics. Implement the end-to-end product features defined in SPEC. Where platform APIs cannot be reliably automated, implement the full compileable integration layer and honest fallback, and mark hardware tests pending.

**Phase C — CI and quality:** Create macOS workflow using unsigned simulator builds, unit/fixture tests, sanity checking dependencies, format/lint when realistic. Run build/test locally if macOS available; otherwise push and inspect GitHub Actions results, fix failures in follow-up commits. No signing secrets, no paid Apple membership needed for unsigned simulator CI.

**Phase D — handoff:** Update README with exact Windows + GitHub + future signing instructions; produce `docs/IMPLEMENTATION_STATUS.md` mapping each acceptance ID to implemented/tested/blocked with evidence. Keep architecture decisions record. Produce short PR with working/tested features, known limitations, GitHub Actions status and next real hardware tests.

## Crucial behavioural tests

- No automatic video transcode, including burning-in subtitle track or Cast fallback; user consent required. Audio-only allowed.
- Restart after stopping at 12 min resumes properly; watched/next-up not double-counted.
- Apple TV profile chooser appears on fresh launch, not just returning from background; iPhone remembers last user; profiles separated.
- 5 sec next episode countdown is cancellable.
- VLC or other local fallback never silently authorizes server video transcoding.
- iPhone downloaded original file works airplane mode, is retained until manual deletion, and offline history syncs on reconnect.
- Legacy Cast 4K incompatibility prompts; no false 'connected' state without actual receiver status.
- Diagnostics export excludes token, API key, auth header, signed link and personally identifying URLs.

## Priority if time or tool limits are reached

1. Compileable iOS/tvOS targets + CI, auth, profiles, libraries, metadata + real Jellyfin client and fixture tests.
2. Playback decision engine, AVPlayer end-to-end, progress/watched, 4K/HDR route design, alternative engine.
3. Google Cast iOS, AirPlay and offline-original downloader/sync; provide compilable vertical slices and explicit unsolved technical blockers.
4. Polish, translations, advanced settings, test expansion.

Work as independently as possible, do not stop after writing a plan. Do not compromise critical correctness for a green CI status. If an external dependency is unworkable, swap to a supported option and document it.
