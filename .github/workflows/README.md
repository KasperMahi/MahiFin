# CI workflow instructions for Codex

This folder intentionally does not contain a fictional, guaranteed-to-work `xcodebuild` workflow before the Xcode project and schemes exist.

During implementation, create e.g. `ci.yml`, pin a standard `macos` GitHub-hosted runner and an Xcode version available on that image, then run unsigned simulator builds for both app schemes (`CODE_SIGNING_ALLOWED=NO`), fixture-backed unit tests, and report exact runner/toolchain versions.

Do not configure TestFlight/App Store signing in CI until Apple Developer membership, certificates and App Store Connect access have been explicitly obtained. CI on private repos can consume/charge included Actions minutes; avoid costly reruns and large runners.
