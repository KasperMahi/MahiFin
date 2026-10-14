# Sources and validation checklist (researched 2026-10-14)

Review freshness/requirements before each implementation milestone:

- Swiftfin source, MPL 2.0 and main's current tvOS version: https://github.com/jellyfin/Swiftfin and https://raw.githubusercontent.com/jellyfin/Swiftfin/main/README.md
- Swiftfin media player capability matrix (especially AVPlayer vs VLC): https://github.com/jellyfin/Swiftfin/blob/main/Documentation/players.md
- Jellyfin Swift SDK and release versions: https://github.com/jellyfin/jellyfin-sdk-swift and https://github.com/jellyfin/jellyfin-sdk-swift/releases
- Jellyfin's Cast web receiver; note it is not sender-side SDK: https://github.com/jellyfin/jellyfin-chromecast
- Google iOS Cast setup/receiver app ID: https://developers.google.com/cast/docs/ios_sender/ and https://developers.google.com/cast/docs/ios_sender/integrate
- Cast iOS local network permissions: https://developers.google.com/cast/docs/ios_sender/permissions_and_discovery
- Apple background URLSession transfers: https://developer.apple.com/documentation/foundation/downloading-files-in-the-background
- GitHub Actions billing/private repository quota: https://docs.github.com/en/billing/concepts/product-billing/github-actions
- Apple Developer membership expiration behaviour: https://developer.apple.com/help/account/membership/renewal/
- TestFlight 90-day expiration: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/

Important unknowns for real test: specific Jellyfin server version/API; actual container/audio/HDR metadata from sample films; Apple TV currently installed tvOS version; Philips ARC soundbar model; Chromecast generation and Cast receiver compatibility; potential MahiFin App Store name or trademark conflict; Apple account enrollment eligibility and App Store review.
