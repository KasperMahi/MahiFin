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
4. Try MKV, TrueHD/DTS, unknown streams and image subtitles. Current build fails with a native compatibility error; inspect server for **no ffmpeg video conversion**. Conversion policy exists but remux/audio conversion/accepted video conversion execution is blocked.
5. Select embedded subtitle/audio tracks in AVKit. Test Jellyfin None/OnlyForced/preferred-language configuration. External SRT and full Smart/default-track preference semantics are not yet integrated. No burn-in fallback.
6. Supply trusted Intro/Outro MediaSegments from the server. Skip appears only within that item's valid interval. No provider/markers: no fabricated skip button. Verify seek end on device.
7. Disconnect network during playback, invalidate token, deny item access. Verify finite timeout/error rather than permanent loading. Report only sanitized diagnostic categories.
8. Test Siri Remote focus/back/scrub, VoiceOver, increased text size, Danish/English, empty/missing artwork.

## Downloads and offline history

1. On iPhone select a single-source compatible original with known Size from details. Download is original /Items/{id}/Download; server must not transcode. Wi-Fi default; enable cellular option and relaunch to verify persistence.
2. Observe progress. Pause/resume; background app, lock device, relaunch after OS eviction. User force quit prevents guaranteed background continuation under iOS rules. Verify manifest and task reconciliation.
3. Test denied storage, low space, expired token/401, partial response, transfer cancellation. Failed transfers show Retry/Delete, no false Complete. Reauthenticate before retrying an expired-token transfer.
4. Finish download; airplane mode **before opening Downloads**. Play/seek file without any server requests. Stop at 12 minutes, kill/reopen, resume from local queue. Finish: retain file until Delete.
5. Switch to user B: A's assets absent. Log A out: active transfer paused and assets retained inaccessible until A authenticates again. Explicit delete frees file and resume-data storage.
6. Reconnect. Foreground/timer/manual Retry history sync uploads partial absolute user data. Repeat retries: favourites preserved, play count unchanged by offline replay. Server newer LastPlayedDate: discard older local event; implausible future clock/equal ambiguous event: retain conflict diagnostic. Exact applied timestamp+state: acknowledge without duplicate write.
7. Simulate device clock ±5 minutes and activity from another client. There is no atomic compare-and-swap API across independent clients: concurrent writes between fetch/post remain a documented limit.

## Hardware release gates

- Apple TV 4K 3rd gen/iPhone: 1080p H.264 AAC/AC3, 4K H.264 verified profile, HEVC Main10 HDR10, Dolby Vision profiles, MKV/audio matrix. Current conservative route rejects HDR without verified capability; do not label these supported from simulator builds.
- Compare HDR output with known sample/display, audio sync, frame rate and HDMI ARC. External CEC/ARC faults remain outside app control.
- AirPlay route picker on iPhone: device selection, seek, output removal, lock/background and reconnect. Distinguish native external output from remote Jellyfin session control.
- Cast is unavailable: discover the signed-in user's Configuration.CastReceiverId, validate the receiver's auth contract and conversion policy, and integrate official sender SDK before testing discovery/load/pause/seek/reconnect on legacy receiver. Current upstream receiver requires account authorization and constructs query-token stream URLs (see decisions/source references). No guessed ID, no fake connected state, no silent video conversion.
- Alternative engine/remux/audio conversion: pin and license-audit an actual compatible SDK and build both platforms; validate tracks/seek/HDR before enabling its capability. Never set alternativeAvailable until a real adapter exists.
