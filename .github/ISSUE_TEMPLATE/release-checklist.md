---
name: Release checklist
about: Track tasks needed before App Store / Google Play release
title: "Release checklist"
labels: release
assignees: ""
---

## Store readiness

- [ ] Enable GitHub Pages for `main` / `/docs`
- [ ] Confirm privacy policy URL opens publicly
- [ ] Fill App Store Connect privacy details
- [ ] Fill Google Play Data safety form
- [ ] Prepare App Store screenshots
- [ ] Prepare Google Play screenshots
- [ ] Confirm app name, icon, and launch screen

## Monetization

- [ ] Replace AdMob test IDs with production IDs
- [ ] Connect real App Store in-app purchases
- [ ] Connect real Google Play Billing
- [ ] Verify free vs Premium feature gating

## Build and signing

- [ ] Configure iOS signing for release
- [ ] Configure Android release keystore
- [ ] Verify `flutter analyze`
- [ ] Verify `flutter test`
- [ ] Build iOS release candidate
- [ ] Build Android release candidate

## Privacy and permissions

- [ ] Confirm microphone usage text
- [ ] Confirm camera usage text
- [ ] Confirm no audio recording or external upload
- [ ] Confirm QR scan data handling

