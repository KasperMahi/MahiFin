# Third-party provenance

Application and tests are original implementation. No Swiftfin/MPL covered source or VLC binaries are copied. Apple system frameworks are supplied by the OS/Xcode. No external runtime packages are linked.

Research references: Jellyfin server/API (GPL-2.0), Swiftfin (MPL-2.0), jellyfin-sdk-swift (MIT), jellyfin-chromecast (GPL-2.0), Google Cast documentation. HTTP interoperability is implemented independently; these projects are not redistributed.

CI uses GitHub checkout and macOS runner tools. Re-audit before adding a player/Cast SDK. Retain package licenses and covered-file source/provenance when dependencies change. Public distribution requires branding, codec and App Store review.
