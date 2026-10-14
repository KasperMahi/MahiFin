# MahiFin — Acceptance test plan

**Labels:** A = automated fixture/unit test; S = simulator UI smoke test; H = physical hardware/integration test. A and S can be used as pre-Developer-membership gates. H cannot be honestly claimed complete from CI alone.

## Functional tests

| ID | Scenario | Expected result | Gate |
|---|---|---|---|
| AUTH-01 | Server URL, Quick Connect flow success and denial | Can link account; handles cancellation and timeout; secrets not logged | A,S,H |
| AUTH-02 | Username/password fallback | Auth persists securely across restart | A,S |
| AUTH-03 | Two profiles on tvOS | Fresh launch shows chooser; returning from temporary background does not; histories remain isolated | A,S,H |
| AUTH-04 | iPhone last-used profile | Reopens correct user; manual switch clears wrong account's cached UI | A,S |
| UI-01 | Library content | Home Continue, Next Up, Recently Added; Films/Series grid; blank art fallback | A,S |
| UI-02 | Filters and search | Genre/year/watched/library filters; single search; no duplicate paging bugs | A,S |
| UI-03 | Detail metadata and seasons | Description/rating/cast; episodes ordered; manual favourite/watched actions update Jellyfin | A,S |
| UI-04 | Languages | Danish and English translations including errors and accessibility labels | A,S |
| PLAY-01 | Resume | Stop 12 minutes into episode; app restart; Continue opens near stored offset, not zero | A,S,H |
| PLAY-02 | Completion | Finish episode; mark watched once; Next Up updates; 5-second auto-next cancellable | A,S,H |
| PLAY-03 | Decision pure functions | Supported MP4 AVPlayer direct; incompatible MKV alt-local/remux; audio-only transcode policy; no silent video transcode | A |
| PLAY-04 | 1080p H.264 + AC3/AAC | Stable seek, no repeated buffering and correct audio | H |
| PLAY-05 | 4K H.264 supported profile | No unwanted resolution downgrade and no silent transcode | A,H |
| PLAY-06 | 4K HEVC Main10 HDR10 | HDR output verified on physical display; appropriate format route | H |
| PLAY-07 | MKV audio variety | Correct sound including alternate language selection where route permits; clear fallback/error for unsupported codecs | H |
| PLAY-08 | Subtitles | Follow Jellyfin preferences; select embedded/external when supported; no unapproved video transcode for subtitle burn-in | A,H |
| PLAY-09 | Intro/credits markers | Show skip only if supplied; seek to marker end; never invent marker | A,S |
| PLAY-10 | Streaming failure | Actionable error + sanitized local diagnostics; no endless spinner | A,S |
| PLAY-11 | Soundbar ARC test | No app-induced audio duplication/delay; external ARC/CEC problems separated from client defects | H |
| CAST-01 | iPhone sees legacy Chromecast | Network permission, discovery, connect; clear error on refusal | S,H |
| CAST-02 | Cast media playback | Play, pause, seek, lock iPhone, reopen/reconnect; server position persists | A,H |
| CAST-03 | 4K/HEVC on non-4K Chromecast | User approves/declines video transcode; decline never starts conversion | A,H |
| CAST-04 | Receiver authorization | Cast device itself can reach/authenticate to stream; no long-lived secrets in logs | A,H |
| AIR-01 | iPhone to AirPlay | Device selection and playback/seek where supported | H |
| OFF-01 | Download original file | Uses original bytes; no conversion; Wi-Fi-only default with cellular override; durable progress | A,S,H |
| OFF-02 | iPhone airplane mode | Downloaded file + metadata play offline with no server calls | A,H |
| OFF-03 | Download persistence | Not auto deleted after watch; manual delete frees space | A,S |
| OFF-04 | Per-user isolation | User B cannot access user A downloads and history | A,S |
| OFF-05 | History sync | Offline events sync when online; duplicate idempotency; latest real event wins within documented clock policy | A,H |
| OFF-06 | Interrupted download | Background/force-stop/disk-full/token-invalid scenarios fail predictably or recover where OS permits | A,H |
| DIAG-01 | Troubleshooting export | Playback path, codec and errors included; tokens/server identity/redactable sensitive data absent | A,S |
| CI-01 | Reproducible clean build | Both iOS/tvOS targets build unsigned for simulator on GitHub macOS | CI |
| CI-02 | Tests and provenance | Unit tests pass; third-party source licenses/notices tracked | CI |

## Media test matrix — fixture types (create or obtain legally shareable short synthetic clips)

- H.264 1080p + AAC in MP4
- H.264 1080p + AC3 in MKV
- H.264 4K supported profile + AAC in MP4
- HEVC 4K Main 10 HDR10 in supported container; known HDR metadata
- HEVC 1080p MKV with EAC3
- MKV with DTS or Opus (demonstrate fallback or sound conversion)
- External SRT, embedded text subtitles, and an image-based subtitle case where transcoding may be requested
- Multi-audio tracks, missing audio, corrupt media, slow connection, invalid metadata, expired token

Do not add copyrighted commercial samples to public repo. Dummy Jellyfin JSON fixtures may include invented titles/names only.

## Definition of Done by phase

**First Codex run (CI gate):** Both app targets compile with documented toolchain; shared domain/auth/library/player-policy works; automated tests; functional navigation using fixture server; app features implemented or clearly tracked as blocked with a working alternative; PR contains build links and frank checklist. NO claim of production readiness.

**Hardware beta gate:** Signed builds via TestFlight, tested on actual Apple TV 4K 3rd gen and iPhone; 4K/HDR, audio sync with soundbar, seeking, Quick Connect, AirPlay, Cast old generation, downloads and offline sync; no silent video transcodes.

**Public release gate:** Cross-version Jellyfin integration smoke tests, licenses, accessibility, security/privacy, app review metadata and demo account/test mode, update strategy and tested upgrade/migration.
