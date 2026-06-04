# GoKarts Racing Lines

SwiftUI iOS prototype for drawing and driving racing lines on top of a live camera view.

## Features

- Portrait home screen with Start, Settings, and Draw actions.
- Camera preview with GPS/CoreMotion backed racing-line overlay.
- Track editor for selecting a circuit area, choosing lap mode, and drawing racing lines.
- AMap/Gaode integration hook with a MapKit fallback for development without the SDK.
- Finger-drawing speed classification: slower strokes are green, faster strokes are red.
- Live route recording mode to build racing lines from actual driving/riding data.

## AMap setup

1. Install pods on macOS:

   ```bash
   pod install
   ```

2. Open `GoKartsRacingLines.xcworkspace`.
3. Add your Gaode iOS key to `GoKartsRacingLines/Resources/Info.plist` under `AMapApiKey`.

Without the AMap SDK, the app compiles against MapKit and keeps the editor workflow available.

## GitHub Actions IPA build

This repository includes `.github/workflows/ios-build.yml` for remote macOS builds.

### What works without signing

- Every push to `main` or `master` runs a simulator compile check on GitHub's `macos-15` runner.
- This confirms the Swift project and CocoaPods dependencies compile, but it does not produce an installable IPA.

### What is required for IPA export

Apple requires a signed archive for an installable IPA. Add these GitHub repository secrets before running the `iOS Build` workflow manually:

| Secret | Required | Description |
| --- | --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Yes | Base64 text of your `.p12` Apple signing certificate. |
| `P12_PASSWORD` | Yes | Password used when exporting the `.p12`. |
| `BUILD_PROVISION_PROFILE_BASE64` | Yes | Base64 text of your `.mobileprovision` profile. |
| `KEYCHAIN_PASSWORD` | Yes | Any temporary password for the CI keychain. |
| `DEVELOPMENT_TEAM` | Yes | Apple Developer Team ID, for example `ABCDE12345`. |
| `BUNDLE_IDENTIFIER` | Optional | Bundle ID matching the provisioning profile. Defaults to `com.rov.gokarts.racinglines`. |
| `AMAP_API_KEY` | Optional | Gaode/AMap iOS API key injected into `Info.plist` during CI. |

On macOS, encode signing files with:

```bash
base64 -i Certificates.p12 | pbcopy
base64 -i Profile.mobileprovision | pbcopy
```

Then open GitHub → repository → Settings → Secrets and variables → Actions → New repository secret.

After secrets are configured, open Actions → `iOS Build` → Run workflow, choose `development`, `ad-hoc`, `app-store`, or `enterprise`, then download the `GoKartsRacingLines-ipa` artifact.

## Permissions

The app requests camera, location, and motion access because racing-line rendering depends on the live camera image, GPS track points, heading, speed, and device attitude.
