# Third-party provenance

Application, Objective-C adapter and tests are original implementation. No Swiftfin/MPL covered source is copied. Apple frameworks are supplied by the OS/Xcode.

## VLCKit / libVLC

Official VideoLAN VLCKit, LGPL-2.1-or-later. Copyright VideoLAN and VLC authors. License retained in Licenses/VLCKit-LGPL-2.1.txt. Package source pinned to revision `2e0868f5ed40fe59cd92f377645fdcc260c6e759` at https://github.com/videolan/vlckit. It references official binary `VLCKit-4.0-20260929-1631.zip` with SHA256 `f37c8dbdd4427d1a3f5d75dc4b8bd1ae863cef4426f9a405a2fd1c5c9012f1fb`. Downloaded by SwiftPM from VideoLAN; no binary copied into Git. Package minimums iOS/tvOS 12; our app minimums stay 18.

Do not publish an app binary until corresponding libVLC/contrib build source and notices for the exact artifact, relinking/replacement materials and distribution terms are preserved and reviewed. Private CI compilation is not a completed public-distribution license audit. No library source is modified here. No universal codec, passthrough or HDR claim is made.

CI uses FFmpeg to generate original synthetic clips only, not as a linked app dependency. Generated test media contains no third-party audiovisual work.

## Google Cast (iOS only)

Official googlecast/google-cast-ios-sdk 4.8.6, GoogleCastDynamic product; exact GTMSessionFetcher 3.0.0. SDK package wrapper copyright Google LLC, Apache-2.0 retained in Licenses/GoogleCast-Package-Apache-2.0.txt. Vendor SDK binary has separate applicable Google Cast SDK terms and embedded notices/privacy metadata; preserve/review those before distribution. Package pins vendor ZIP checksum `55f6c21291a1315c68063f07e7d76225564bff70f2fd38caad135c71d66eb310`. No binary copied into Git. No app analytics/log collector added; raw SDK logs dropped. Discovery is explicit user action. Receiver credential/media loading remains blocked by audited remote token logging.

GTMSessionFetcher 3.0.0 is an unmodified source dependency from https://github.com/google/gtm-session-fetcher/tree/v3.0.0, copyright Google authors, Apache-2.0. Its upstream license is retained separately in Licenses/GTMSessionFetcher-Apache-2.0.txt; preserve upstream source copyright headers when distributing corresponding materials.

Research references: Jellyfin server/API (GPL-2.0), Swiftfin (MPL-2.0), jellyfin-sdk-swift (MIT), jellyfin-chromecast (GPL-2.0), Google Cast documentation. HTTP interoperability is implemented independently; these projects are not redistributed.

CI uses GitHub checkout and macOS runner tools. Re-audit before changing SDK pins or adding dependencies. Retain package licenses and covered-file source/provenance when dependencies change. Public distribution requires branding, codec and App Store review.
