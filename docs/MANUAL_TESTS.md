# Device and integration repro procedures

All server URLs/accounts remain local. Use a disposable test user and synthetic media. Never attach raw request/AVPlayer logs with URLs to a public issue. No live integration tests have been performed in this run.

## Setup and account isolation

1. Open MahiFin.xcodeproj in Xcode 16.4+, choose MahiFin-iOS or MahiFin-tvOS, select your development team for physical devices. Minimum OS is 18.
2. Connect to a Jellyfin 10.10+ HTTPS server (reverse-proxy base paths supported). Sign in with password; quit/relaunch. Verify no token in accounts.json/history.json or diagnostics. Inspect Keychain locally, never export it.
3. Add a second independent user through Settings. Switch. Verify previous posters, resume and favourites disappear; no owner/admin impersonation.
4. On Apple TV kill app and cold launch: chooser must appear even with one profile. Background/foreground briefly: selected profile stays selected. On iPhone cold launch: last profile opens.
5. Quick Connect: authorize displayed code using signed-in Jellyfin UI. Cancel, disable Quick Connect, allow two-minute client timeout, enter wrong password. Verify actionable localized errors and cancellation do not log in later.

## Catalog and native playback

1. Populate two movie and two series libraries. Check all three Home rows, source filters, genre/year/unwatched sorting and paging beyond 60 items. Search across libraries, delete query while a request is in flight. Episode list must remain season/episode ordered.
2. Play synthetic MP4 H.264/AAC. Seek to 12 minutes; pause, exit, relaunch and resume. Inspect Jellyfin position and session events. Repeated exit must not double-increment play count.
3. Complete an episode. Verify watched/next-up on Jellyfin. Verify five-second countdown, Cancel immediately and at second four; no later autoplay. Navigate away during countdown. Verify next episode starts with correct source/session.
4. Run `python3 scripts/generate_media.py` (ffmpeg required) and import the authored MKV/MP4/SRT to a disposable library. Automatic mode should choose VLCKit for compatible SDR MKV. Seek, pause/play, select audio/subtitles, finish naturally, then exit early: only natural completion marks watched. Repeat downloaded MKV in airplane mode. Test EAC3/TrueHD/DTS/Opus separately; the AAC clip proves none of those codecs or physical output.
5. Select Native engine preference to exercise copy fallback. For compatible video in MKV verify Jellyfin's actual ffmpeg command uses **video copy**; unsupported audio should encode only audio. Confirm no sizing/tone-map/deinterlace/burn-in. Unsupported video must prompt: Cancel creates no stream or encoding; Accept applies to that item/source only. Navigate away/fail/retry and check DELETE Videos/ActiveEncodings cleanup. Test 10.10/10.11/12 separately; fMP4 HLS codec compatibility is not established by request tests.
6. Select embedded subtitle/audio tracks in AVKit and VLCKit. Test Jellyfin None/OnlyForced/preferred-language configuration on native playback. External SRT, alternative-engine preference application and full Smart/default semantics remain unfinished. Never burn in without video consent.
7. Supply trusted Intro/Outro MediaSegments from the server. Skip appears only within that item's valid interval. No provider/markers: no fabricated skip button. Verify seek end on device.
8. Disconnect network during playback, invalidate token, deny item access. Verify finite timeout/error rather than permanent loading. Report only sanitized diagnostic categories.
9. Test Siri Remote focus/back/scrub, VoiceOver, increased text size, Danish/English, empty/missing artwork.

## Downloads and offline history

1. On iPhone select a single-source compatible original with known Size from details. Download is original /Items/{id}/Download; server must not transcode. Wi-Fi default; enable cellular option and relaunch to verify persistence.
2. Observe progress. Pause/resume; background app, lock device, relaunch after OS eviction. User force quit prevents guaranteed background continuation under iOS rules. Verify manifest and task reconciliation.
3. Test denied storage, low space, expired token/401, partial response, transfer cancellation. Failed transfers show Retry/Delete, no false Complete. Reauthenticate before retrying an expired-token transfer.
4. Finish download; airplane mode **before opening Downloads**. Play/seek file without any server requests. Stop at 12 minutes, kill/reopen, resume from local queue. Finish: retain file until Delete.
5. Switch to user B: A's assets absent. Log A out: active transfer paused and assets retained inaccessible until A authenticates again. Explicit delete frees file and resume-data storage.
6. Reconnect. Foreground/timer/manual Retry history sync uploads partial absolute user data. Repeat retries: favourites preserved, play count unchanged by offline replay. Successful upload then airplane mode/relaunch must still resume locally. Server newer LastPlayedDate: refresh local snapshot/discard older pending event; implausible future clock/equal ambiguous event: retain that conflict but upload unrelated items. Exact applied timestamp+state: acknowledge without duplicate write.
7. Simulate device clock ±5 minutes and activity from another client. There is no atomic compare-and-swap API across independent clients: concurrent writes between fetch/post remain a documented limit.

## Hardware release gates

- Apple TV 4K 3rd gen/iPhone: 1080p H.264 AAC/AC3, 4K H.264 verified profile, HEVC Main10 HDR10/HLG, Dolby Vision profiles, MKV/audio matrix. Native HDR routing requires Apple modes and known metadata; local-engine HDR and unverified DV remain blocked. Do not claim physical output from eligibility probes or simulator builds.
- Compare HDR output with known sample/display, audio sync, frame rate and HDMI ARC. External CEC/ARC faults remain outside app control.
- AirPlay route picker on iPhone: device selection, seek, output removal, lock/background and reconnect. Distinguish native external output from remote Jellyfin session control.
- Cast discovery/session controls: use Settings → Cast → Find receiver with a configured stable/unstable ID and declared Bonjour service. Allow/deny Local Network permission, connect/disconnect/reconnect, then test existing media pause, consent-cancel/accept resume/seek and source-change rejection. Jellyfin auth/load must remain disabled until the audited receiver logs are redacted and its per-load/track/seek video conversion policy is constrained and tested on the deployed revision. Inspect both receiver and sender logs locally without exporting secrets. Legacy 4K/HEVC must never convert without consent. Receiver history/lock-screen controls remain unfinished.
- Before distributing SDK-linked binaries, complete exact VLCKit/libVLC/contrib corresponding-source/notices/relinking materials and Google binary terms/privacy review. See THIRD_PARTY_NOTICES.md.
