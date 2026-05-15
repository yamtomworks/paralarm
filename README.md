# Par-alarm

Par-alarm is a Flutter app for iPhone and Android that monitors volume or vibration and alerts when a configured threshold condition is met.

The app is designed around a dark graphite and neon lime UI, realtime trend charts, configurable alarms, and preset sharing.

## Features

- Monitor volume from the microphone
- Monitor vibration from device motion sensors
- Choose alert condition: above or below threshold
- Realtime graph showing current value and threshold
- Countdown before monitoring starts
- Moving average filter for smoother judgment
- Alarm sound and vibration pattern settings
- Danger zone alert feature for Premium mode
- Setting presets
- QR-based preset sharing for Premium mode
- Test AdMob banner area
- In-app review prompt flow
- First-launch tutorial
- App icon and launch screen assets

## Privacy

Par-alarm uses microphone access only to calculate volume level on device. Audio is not recorded, saved, or sent outside the app.

Camera access is used only for QR code scanning. Camera video is processed on device for scanning and is not saved or sent outside the app.

Privacy policy files are in `docs/`.

- GitHub Pages target: `docs/privacy_policy.html`
- Expected published URL: `https://yamtomworks.github.io/paralarm/privacy_policy.html`

## Development

```bash
flutter pub get
flutter run
```

Run checks:

```bash
flutter analyze
flutter test
```

Build debug packages:

```bash
flutter build apk --debug
flutter build ios --debug --no-codesign
```

## Release Notes For Maintainers

Before public release, replace test or demo-only settings:

- Replace AdMob test App ID / Ad Unit ID with production IDs.
- Replace the demo Premium unlock flow with real in-app purchases.
- Confirm App Store Connect privacy details.
- Confirm Google Play Data safety form.
- Publish the privacy policy using GitHub Pages.
- Prepare App Store / Google Play screenshots.
- Configure real iOS signing and Android release signing.

## Repository

GitHub Pages should be configured from:

- Branch: `main`
- Folder: `/docs`
