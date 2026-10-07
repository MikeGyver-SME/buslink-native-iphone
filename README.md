# BusLink Native iPhone V1.2 — CarPlay Status Widget

BusLink V1.2 adds a **systemSmall WidgetKit status widget** designed for iPhone, StandBy, and CarPlay while preserving the proven V1.1 app and V1.4 Worker behavior.

## What the widget shows

- `READY` when the bus event and Shaira arrival are both confirmed.
- `BUS NEAR` when the bus event is confirmed first.
- `SHAIRA THERE` when Shaira arrives first.
- `AM WATCH` / `PM WATCH` while monitoring with no event yet.
- `WEEKEND`, `SCHOOL OFF`, or `STANDBY` when monitoring is paused.
- Compact bus and Shaira rows (`1-MILE`, `ALMOST HOME`, `AT STOP`, `AWAY`, `WAITING`).
- Last widget refresh time.

The widget is **read-only**. It calls only:

`https://buslink.mikegyver.workers.dev/api/state`

No BusLink event/admin secret is embedded and no write endpoint is called.

## CarPlay behavior

Apple uses the app's `systemSmall` widget for CarPlay. The widget uses a removable WidgetKit background and large, glanceable status text. On iOS 27, add **BusLink Status** from the CarPlay Widgets screen after installing V1.2.

### Important freshness note

WidgetKit controls refresh timing. During an active watch this package requests a new timeline after 60 seconds, but iOS may coalesce or delay refreshes. The widget therefore complements — not replaces — the proven iPhone Shortcuts, Worker, native app, and Windows Watchdog event pipeline.

When the native BusLink app successfully refreshes, it also calls `WidgetCenter.reloadTimelines(ofKind: "BusLinkStatusWidget")` to request an immediate widget refresh.

## Version

- App: **1.2.0**
- Build: **3**
- Main bundle ID: `studio.mikegyver.buslinknative`
- Widget bundle ID: `studio.mikegyver.buslinknative.widget`
- Worker/API: unchanged

## GitHub Actions / AltStore deployment

1. Back up the current V1.1 repo/commit (`d0ea53f`) as the known-good rollback.
2. Copy this package over the existing `buslink-native-iphone` repository **without deleting the existing `Assets.xcassets/AppIcon.appiconset/AppIcon.png`**. The package intentionally does not replace your proven BusLink app icon.
3. Commit and push to `main`.
4. The existing GitHub macOS workflow generates the Xcode project, compiles the app + widget extension, verifies the `.appex` is embedded, and uploads `BusLinkNative-v1.2.0-carplay-unsigned-ipa`.
5. Download the artifact ZIP and extract `BusLinkNative-unsigned.ipa`.
6. Install/sign it with your proven AltServer/AltStore workflow.
7. On iPhone, verify **BusLink Status** appears in the widget gallery.
8. Connect to CarPlay and add **BusLink Status** from CarPlay's Widgets screen.

## TestFlight path

The source is TestFlight-ready, but TestFlight requires a signed archive/export using your Apple Developer team and App Store Connect credentials/provisioning. The included workflow intentionally remains the proven unsigned-IPA workflow and does **not** contain Apple signing secrets.

For TestFlight, generate the same project with XcodeGen on a signed macOS runner or Xcode, archive the `BusLinkNative` scheme with your Developer Team, then upload the archive through Xcode/Transporter or a separately configured App Store Connect workflow.

## Acceptance test

During an AM or PM watch:

1. Open the normal BusLink app and confirm it matches the web dashboard.
2. Add the BusLink Status widget on iPhone and verify its state.
3. Connect CarPlay and add BusLink Status.
4. When Stopfinder triggers a bus event, verify the authoritative Worker/web/native state first.
5. Observe the CarPlay widget update. Do not treat sub-minute widget timing as guaranteed; WidgetKit owns refresh scheduling.
6. Verify Shaira arrival and `READY` state.
7. Confirm weekend/school-off states remain correct.

## Rollback

Reinstall/build V1.1 from commit `d0ea53f` if the widget extension causes any deployment issue. The Worker and Shortcuts do not need to change for rollback.
