# BusLink Native iPhone V1.1 — School Calendar Awareness

This SwiftUI app remains a native, read-only observer of the BusLink Worker.

## V1.1 changes

- Monday–Friday local watch guard remains in place; Saturday/Sunday make no watch-period network calls.
- During a weekday AM/PM window, the Worker is authoritative for school holidays/breaks.
- If V1.4 reports `school-off`, the app displays **SCHOOL OFF** and pauses automatic 10-second refreshes for that local window.
- Weekend UI displays **WEEKEND**.
- The fractional-second ISO-8601 event timestamp fix remains intact.
- No event/admin secret is embedded in the app and no write endpoint is called.

The app continues to read:

`https://buslink.mikegyver.workers.dev/api/state`

## Build without a Mac

1. Replace the contents of the existing `buslink-native-iphone` GitHub repository with this package (including `.github`).
2. Push to `main` or run **Build BusLink iPhone IPA** manually.
3. Download the `BusLinkNative-unsigned-ipa` artifact.
4. Install the unsigned IPA using the same AltServer workflow already proven for the user's native iOS apps.

`MARKETING_VERSION` is 1.1.0 and build number is 2.

## Operational behavior

- Normal weekday watch: refreshes every 10 seconds while open.
- Weekend: standby; no watch polling.
- School-off weekday: one authoritative check when the local watch is reached, then standby for that window.
- Manual Refresh during a local weekday watch can force a schedule re-check after changing School Off/On.
- iPhone Shortcuts and the Windows Watchdog remain responsible for event detection/laptop alerts; the native app is an observer.

## Validation performed before packaging

- Swift parser check passed for all source files in the build environment.
- `WatchSchedule` compiled and passed a Friday-AM / Saturday-suppression smoke test using Foundation.
- Full SwiftUI/iPhone compilation must still be verified by the GitHub macOS Action, as before.
