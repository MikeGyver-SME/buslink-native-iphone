# BusLink V1.2 CarPlay Deployment Checklist

- [ ] Keep V1.1 commit `d0ea53f` as rollback.
- [ ] Copy package into canonical `buslink-native-iphone` repo.
- [ ] Confirm only intended V1.2 files changed.
- [ ] Commit: `Release BusLink Native v1.2.0 CarPlay status widget`
- [ ] Push `main`.
- [ ] GitHub Action passes **Verify embedded widget**.
- [ ] Download `BusLinkNative-v1.2.0-carplay-unsigned-ipa` artifact.
- [ ] Install with AltServer/AltStore (or sign/archive for TestFlight).
- [ ] Launch BusLink once after upgrade.
- [ ] Add `BusLink Status` to iPhone Home Screen for quick validation.
- [ ] Connect CarPlay and add `BusLink Status` from Widgets.
- [ ] Validate `STANDBY` outside watch.
- [ ] Validate `AM WATCH` or `PM WATCH` during watch.
- [ ] Validate bus-only state.
- [ ] Validate Shaira-only state.
- [ ] Validate `READY` when both events are present.
- [ ] Validate `WEEKEND` and next school-off day when convenient.
- [ ] Do not change Worker, Stopfinder Shortcuts, or event secret for this release.
