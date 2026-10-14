# Implementation decisions — 14 October 2026

## Audit

- Clean specification-only repository; no inherited application code or dependencies.
- Windows execution host has no Swift/Xcode. Apple builds/tests must run on GitHub macOS; hardware results remain pending.
- Verified private GitHub repository and push permissions. No visibility changes, secrets or live server data.
- [Swiftfin main](https://github.com/jellyfin/Swiftfin) currently requires tvOS 26, iOS 18 and Jellyfin 12. Its MPL-2.0 source is not copied. Earlier implementations inform architecture only.
- [Official SDK](https://github.com/jellyfin/jellyfin-sdk-swift) is generated against newer server contracts. Use a small URLSession boundary against stable Jellyfin 10.10 endpoints instead of binding to generated 12-only models. Minimum handshake: 10.10; future majors pass the minimum-version check, but require live compatibility validation. Live 10.10/10.11/12 tests pending.
- API reference: Jellyfin controllers at [v10.10.7](https://github.com/jellyfin/jellyfin/tree/v10.10.7/Jellyfin.Api/Controllers). Implement public info, password/Quick Connect, items/views/resume/next-up, playback info and session reporting, watched/favourite and original download. Fixture tests inspect requests; no invented SDK signatures.
- Native AVKit supports conservative MP4/MOV H.264/HEVC + AAC/AC3/EAC3 routing. HDR, Dolby Vision, passthrough and 4K profiles require device testing. Unknown streams fail closed. No MKV blanket transcoding rule.
- Do not ship speculative VLC binaries or licenses. Isolate alternative engine capability behind policy; unavailable engine is explicitly blocked. Native-compatible originals remain usable.
- [Google Cast integration](https://developers.google.com/cast/docs/ios_sender/integrate) requires receiver application ID, session callbacks and actual receiver status. [Jellyfin receiver](https://github.com/jellyfin/jellyfin-chromecast) needs a verified protocol/auth strategy. No credentials in Cast URLs, no fabricated connection. Cast release gate remains blocked; provide a protocol and honest unavailable state rather than an unverified SDK dependency.
- [Background downloads](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background): iOS URLSession background identifier, delegate delivery, durable per-account manifest, authenticated original endpoint, cellular disabled by default, file protection and backup exclusion. Force quit recovery follows iOS limits; no promise of continued transfer after user termination.
- Opaque URLSession resume data may contain authorization headers: app-retained resume blobs use device-only Keychain, not JSON/files. iOS maintains its own protected background-session state. Resume after token renewal may fail once; failed-transfer retry builds a fresh authenticated request. Delegate task IDs prevent replaced-transfer callbacks from changing current records.
- Diagnostics use an allowlisted structured report (route/codecs/error categories) rather than trying to regex-redact arbitrary server text.
- Generated Xcode project uses only Apple frameworks and a local Swift package. No third-party runtime source. Generator is checked in; CI checks reproducibility.

## Correctness limits

No server-side conversion stream is issued by the initial native path. Remux/audio conversion/video consent policy is modelled and tested, but actual conversion negotiation is blocked until media-profile contract integration is verified. This is a safe fallback, not a completed conversion feature.

Static streaming is allowed only when metadata explicitly declares VideoFile (not BluRay/DVD or missing type). Upstream VideosController has a disc-source encoding branch even with Static=true, so fail closed before constructing that URL. Tests cover missing/disc type rejection. Original downloads are a separate byte endpoint and accept one unambiguous source.

History is durable per account, coalesced per item and retries absolute position/played state through nullable UpdateUserItemDataDto. Applied timestamp+state acknowledges a lost response without another mutation. Jellyfin has no general idempotency key for session posts: session activity is best effort, never described as exactly-once over a failed response. Playing/Progress/Stopped requests are serialized for each playback object; late generation callbacks are ignored. Offline conflict detection compares server LastPlayedDate against stable local activity timestamps; equal ambiguous or implausibly future dates retain a conflict. Missing LastPlayedDate permits upload (first playback); a known newer server date discards older queued activity. Favourites and play counts are not touched by offline replay. No cross-client compare-and-swap API is available.
