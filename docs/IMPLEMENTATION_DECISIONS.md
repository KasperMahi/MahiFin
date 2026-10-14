# Implementation decisions — 14 October 2026

## Audit

- Clean specification-only repository; no inherited application code or dependencies.
- Windows execution host has no Swift/Xcode. Apple builds/tests must run on GitHub macOS; hardware results remain pending.
- Verified private GitHub repository and push permissions. No visibility changes, secrets or live server data.
- [Swiftfin main](https://github.com/jellyfin/Swiftfin) currently requires tvOS 26, iOS 18 and Jellyfin 12. Its MPL-2.0 source is not copied. Earlier implementations inform architecture only.
- [Official SDK](https://github.com/jellyfin/jellyfin-sdk-swift) is generated against newer server contracts. Use a small URLSession boundary against stable Jellyfin 10.10 endpoints instead of binding to generated 12-only models. Minimum handshake: 10.10; unknown future majors allowed with compatibility warning, not a compatibility claim. Live 10.10/10.11/12 tests pending.
- API reference: Jellyfin controllers at [v10.10.7](https://github.com/jellyfin/jellyfin/tree/v10.10.7/Jellyfin.Api/Controllers). Implement public info, password/Quick Connect, items/views/resume/next-up, playback info and session reporting, watched/favourite and original download. Fixture tests inspect requests; no invented SDK signatures.
- Native AVKit supports conservative MP4/MOV H.264/HEVC + AAC/AC3/EAC3 routing. HDR, Dolby Vision, passthrough and 4K profiles require device testing. Unknown streams fail closed. No MKV blanket transcoding rule.
- Do not ship speculative VLC binaries or licenses. Isolate alternative engine capability behind policy; unavailable engine is explicitly blocked. Native-compatible originals remain usable.
- [Google Cast integration](https://developers.google.com/cast/docs/ios_sender/integrate) requires receiver application ID, session callbacks and actual receiver status. [Jellyfin receiver](https://github.com/jellyfin/jellyfin-chromecast) needs a verified protocol/auth strategy. No credentials in Cast URLs, no fabricated connection. Cast release gate remains blocked; provide a protocol and honest unavailable state rather than an unverified SDK dependency.
- [Background downloads](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background): iOS URLSession background identifier, delegate delivery, durable per-account manifest, authenticated original endpoint, cellular disabled by default, file protection and backup exclusion. Force quit recovery follows iOS limits; no promise of continued transfer after user termination.
- Diagnostics use an allowlisted structured report (route/codecs/error categories) rather than trying to regex-redact arbitrary server text.
- Generated Xcode project uses only Apple frameworks and a local Swift package. No third-party runtime source. Generator is checked in; CI checks reproducibility.

## Correctness limits

No server-side conversion stream is issued by the initial native path. Remux/audio conversion/video consent policy is modelled and tested, but actual conversion negotiation is blocked until media-profile contract integration is verified. This is a safe fallback, not a completed conversion feature.

History is durable per account, coalesced per item and retries absolute played/watched state. Jellyfin has no general idempotency key for session posts: session activity is best effort, never described as exactly-once over a failed response. Offline conflict detection compares server LastPlayedDate against stable local activity timestamps; unknown or skewed clocks retain the event and surface a conflict, rather than overwrite newer server history. Favourites/watched edits are independent of playback positions.
