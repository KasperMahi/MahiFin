# Signing and TestFlight preparation

Status: **documented future procedure, not executed or distribution-approved**. No paid enrollment, signing certificate, API key, provisioning profile, archive, upload or tester invitation is required now. Both minimum deployment targets remain iOS/tvOS 18.

## Toolchain and release gates

The existing Xcode 16.4 unsigned CI is the last verified development gate. Apple's [current upload table](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/) checked 2026-10-15 requires iOS/tvOS builds made with Xcode 26 or later. Therefore a successful current development build is insufficient for TestFlight. Before enabling distribution, select a **specific available** Xcode 26+ runner/toolchain, run both unsigned builds and all core/UI/integration tests on the exact release SHA, adapt compatibility issues, and verify deployment targets remain 18. Do not change the development pin or claim the new compiler validated until that run succeeds. Recheck Apple's requirements before use.

Record exact release SHA, runner image/Xcode build, package checksums, real Jellyfin run/image digests, device results and license evidence. Close the current startup failure and server-validation gates first. Signed archives and beta delivery remain pending even after unsigned tests pass.

## Dependencies: close before any binary distribution, including TestFlight

| Dependency | Retained evidence | Required before distribution |
|---|---|---|
| VLCKit / libVLC LGPL-2.1-or-later | Wrapper revision/checksum and license in THIRD_PARTY_NOTICES.md / Licenses | Obtain exact binary's complete corresponding libVLC/contrib sources, patches, build configuration/scripts and component notices; review the LGPL section 6 relinking/replacement route and user modification/debugging rights for the actual signed iOS/tvOS delivery |
| Google Cast 4.8.6 (iOS only) | Exact SDK checksum, Apache wrapper license | Review vendor binary terms, embedded third-party notices, signatures, privacy manifests and application declarations; wrapper Apache license is not a blanket SDK license |
| GTMSessionFetcher 3.0.0 | Exact source pin and Apache license retained | Preserve upstream notices and include applicable runtime notices |
| Future copied MPL files | No Swiftfin source copied currently | Preserve file notices and provide covered source for any future adapted MPL files |

At VLCKit revision `2e0868f5ed40fe59cd92f377645fdcc260c6e759`, [compileAndBuildVLCKit.sh](https://github.com/videolan/vlckit/blob/2e0868f5ed40fe59cd92f377645fdcc260c6e759/compileAndBuildVLCKit.sh) names libVLC `TESTEDHASH=005e69e67`. This is build-script intent, **not provenance proof** for the downloaded nightly artifact. Obtain its actual build manifest, matching libVLC/contrib revisions, patches, enabled modules and codec licenses from the supplier; archive source and build/relinking materials with integrity hashes. The wrapper source alone is insufficient. [Upstream README](https://github.com/videolan/vlckit/blob/2e0868f5ed40fe59cd92f377645fdcc260c6e759/README.md) and retained LGPL sections 4/6 guide the review. Document a workable source access and modified-library relinking/replacement mechanism, including object/source materials and platform signing constraints, before approval. Dynamic linkage alone does not close this review.

For Cast, review the [vendor terms](https://developers.google.com/cast/docs/terms) and required Cast button/branding behavior; review the [official iOS setup](https://developers.google.com/cast/docs/ios_sender) for local-network/Bonjour declarations. Inspect the resolved SDK's privacy manifests and [Apple privacy requirements](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk), and fill App Store privacy answers from actual SDK/app behavior. No claim is made that disabling app analytics removes vendor SDK behavior. Complete the receiver security gate separately.

## Owner setup later

1. Enroll only when the owner chooses. Register the two current identifiers `dk.mahifin.ios` and `dk.mahifin.tvos`, or make a reviewed identifier migration. Create corresponding App Store Connect platform records and select a team. Confirm whether these are separate records or a deliberate universal-purchase arrangement before uploading.
2. Create Apple Distribution identity plus App Store provisioning profiles for each identifier. Use an App Store Connect API key with the minimum role/app access needed for upload. Restrict its ownership, rotate/revoke it, never commit `.p8`, `.p12` or profiles. Upload authorization and code signing are separate credentials.
3. Create a protected GitHub environment `testflight` with required reviewers and allowed release branch/tags. Store certificate/profile/key bytes in environment secrets. Store team ID, key ID, issuer and profile names as scoped configuration; never print their secret values. Require an explicit workflow_dispatch upload boolean defaulting to false; do not trigger signing/upload on pull_request or pull_request_target.
4. Require release/test/license evidence for the exact SHA before environment approval. Do not give untrusted branch code or third-party PR actions access to these secrets. Pin any additional signing/upload action to a reviewed immutable revision. Retain only approved IPA/dSYM artifacts privately with short retention; exclude keychain, profiles, `.p8`, raw build environment and secret-bearing logs.

## GitHub Actions workflow recipe

Implement the future manually dispatched release workflow after the above gates. Use separate stages: credential-free verification -> protected signed archive/export -> optional explicit upload. Matrix parameters are:

| Platform | Scheme | Generic destination | Bundle identifier | Upload platform |
|---|---|---|---|---|
| iOS | MahiFin-iOS | generic/platform=iOS | dk.mahifin.ios | ios |
| tvOS | MahiFin-tvOS | generic/platform=tvOS | dk.mahifin.tvos | appletvos |

On an ephemeral macOS runner, disable shell tracing, set umask 077, create a randomly named temporary keychain, import the distribution identity from a secret-created `.p12`, and install only the profile for that matrix target. Configure the temporary keychain for noninteractive codesign access. Record the original keychain search list and restore it in an EXIT trap. The trap must delete only that run's temporary keychain/profile/key directory, including on failure/cancellation. Never modify a user's persistent keychain or print `security find-identity`/profile contents to CI logs. Pin DEVELOPER_DIR to the validated Xcode path; generate the synthetic fixtures before archive if the project still references their resources.

The archive stage uses these real Xcode command shapes (variables are future scoped configuration, no credentials included):

```sh
xcodebuild -resolvePackageDependencies -project MahiFin.xcodeproj
xcodebuild -project MahiFin.xcodeproj -scheme "$SCHEME" \
  -configuration Release -destination "$DESTINATION" \
  -archivePath "$PRIVATE_OUTPUT/MahiFin.xcarchive" archive \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Distribution' \
  PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \
  CURRENT_PROJECT_VERSION="$UNIQUE_BUILD_NUMBER"
xcodebuild -exportArchive -archivePath "$PRIVATE_OUTPUT/MahiFin.xcarchive" \
  -exportPath "$PRIVATE_OUTPUT/export" -exportOptionsPlist "$EXPORT_OPTIONS"
```

Create ExportOptions.plist locally in the job with `method=app-store-connect`, `destination=export`, `signingStyle=manual`, `teamID`, `signingCertificate=Apple Distribution` and `provisioningProfiles` mapping that platform's bundle ID to its profile name. Validate current options with the chosen `xcodebuild -help`; do not use automatic upload destination or `-allowProvisioningUpdates` as a workaround for missing provisioning. A unique monotonic build number must be assigned to each platform record. Inspect the exported app's MinimumOSVersion, entitlements, embedded profile, frameworks, privacy manifests and notices before upload.

The optional upload stage creates `AuthKey_<keyID>.p8` in the runner's private API-key directory using the protected secret, invokes Xcode's documented `xcrun altool --validate-app` and `--upload-app` with the exported IPA, platform, `--apiKey` and `--apiIssuer`, and removes that directory in its cleanup trap. Confirm current API-key lookup/options with `xcrun altool --help` on the validated toolchain. Never put a password/private key on a command line or log JWTs. Apple also supports Transporter; do not introduce an unreviewed upload service. Archive/export/upload commands remain **untested** until actual owner-provisioned execution.

## After upload

Wait for App Store Connect processing; resolve validation/export-compliance/privacy issues. First select an internal TestFlight group explicitly, run MANUAL_TESTS on iPhone and Apple TV, then prepare external testing information/review if wanted. Uploading does not itself publish to the App Store or authorize invitations. Public submission/release remains a separate owner action. Keep the draft implementation PR open and unmerged until requested otherwise.
