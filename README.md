# BusLink Native V1.2.1 — Widget Registration Fix

Corrective overlay for V1.2.0. No Worker, Shortcut, widget Swift logic, native state logic, bundle ID, or app-icon changes.

## Fix
XcodeGen is now the source of truth for the widget Info.plist and explicitly generates:
`NSExtension -> NSExtensionPointIdentifier = com.apple.widgetkit-extension`.

The GitHub Action now inspects the BUILT extension Info.plist and fails unless that exact value survived generation/compilation.

Version: **1.2.1**, build **4**.

## Apply
Copy these three files over the canonical repo:
- `project.yml`
- `.github/workflows/ios-build.yml`
- `BusLinkWidget/Info.plist`

Then run:

```powershell
cd E:\ios_dev\buslink-native-iphone
git status
git diff -- project.yml .github/workflows/ios-build.yml BusLinkWidget/Info.plist
git add project.yml .github/workflows/ios-build.yml BusLinkWidget/Info.plist
git commit -m "Release BusLink Native v1.2.1 widget registration fix"
git push origin main
```

The GitHub Action must show `Verify embedded WidgetKit registration` and print:
`Built widget extension point: com.apple.widgetkit-extension`

Only then install artifact:
`BusLinkNative-v1.2.1-widget-registration-fix-unsigned-ipa`

After installation: launch BusLink once, then Home Screen -> Edit -> Add Widget -> search BusLink. Test CarPlay only after iPhone widget discovery passes.

Rollback: V1.1 `d0ea53f`. Failed-discovery baseline: V1.2.0 `b2d6b50`.
