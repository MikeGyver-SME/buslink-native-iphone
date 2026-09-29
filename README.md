# BusLink native iPhone field test

This SwiftUI app is a native, read-only view of the existing BusLink Worker. It displays the AM/PM watch, Colin's bus and Shaira status, event history, and connection state. It reads the Worker every 10 seconds **only while open during a weekday watch**: Monday–Friday 8:15–8:59 AM and 4:15–4:59 PM America/Chicago (automatically CST or CDT). It makes no Worker calls outside those windows, including Saturday and Sunday. Pull-to-refresh and the manual refresh button also respect that gate. Optional local notification banners are delivered for newly discovered events while the app is active.

The app reads `https://buslink.mikegyver.workers.dev/api/state` without a secret. Confirm this is your deployed Worker URL before building; if different, edit `stateURL` in `Sources/BusLinkState.swift`. It does not call event or reset endpoints, contain `BUSLINK_EVENT_SECRET`, modify Durable Object storage, or change the current Stopfinder Shortcuts. It runs beside the existing web dashboard and Windows Watchdog.

Off watch, the dashboard says **Paused** and **connection untested** because it does not contact the Worker. During a weekday watch it shows **Connecting** only while the first request is in flight, **Updated** after a successful response, or **Worker check failed** with the request error and automatic retry if a check fails. A past successful update remains visible with its timestamp if a later check fails. Native `URLSession` requests are not subject to browser CORS rules.

## Important alert limitation

iOS does not promise regular 10-second network polling when an app is closed or in the background. This app is **not** a replacement for the existing iPhone Shortcuts or Windows Watchdog, and it does not promise a background iPhone alert at the one-mile loop. It may display a new banner only while it is open and polling. On first launch, existing event history becomes a baseline and is shown on screen without a delayed alert. When a new event arrives, the app records it as seen even if alert permission is denied. Enable alerts before your watch period to hear them in the app.

## Build without a Mac

1. Create an empty GitHub repository, for example `buslink-native-iphone`. Unzip this package and push **its contents** (including `.github`) to `main`.
2. GitHub Actions starts **Build BusLink iPhone IPA** on each push. You can also run it manually. Open the successful run's **Artifacts** and download `BusLinkNative-unsigned-ipa`.
3. Unzip the artifact download and install `BusLinkNative-unsigned.ipa` with Sideloadly on Windows using your Apple Account and connected iPhone. Developer Mode and developer trust are already familiar from PrismCam/Wiggs Locator. The free signing interval is about seven days.
4. Open BusLink during a weekday watch. Verify the current watch and server state match the browser dashboard. Tap **Enable alerts while app is open** and allow notifications if desired. Outside a watch, the app shows standby without contacting the Worker.

This package was checked for source and ZIP integrity here. Compilation and device behavior must be verified by the GitHub run and your iPhone. The first live test should compare the native dashboard with `/api/state` and the existing web dashboard during a watch window.
