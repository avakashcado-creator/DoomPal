# DoomPal

A free, open-source reel counter and blocker for Android. Counts how many reels you scroll in
Instagram, YouTube Shorts, Facebook and Snapchat, keeps your full history for free, and blocks
reels after your daily limit.

- No accounts, no ads, no paywalls, no internet permission. Everything stays on your phone.
- Per-app and total daily limits, "block completely" mode, hard mode (no snooze).
- Unlimited history with CSV export.
- Built-in detection log for tuning when apps change their screens.

## How it works

An Android Accessibility Service listens only to the four apps (see
`android_overlay/res/xml/accessibility_service_config.xml`). A reel is counted when a vertical
swipe starts on the reels screen:

1. A burst of scroll events is treated as one swipe (400 ms quiet gap, max one count per 700 ms).
2. If the scrolled view's id matches a reels keyword in `Targets.kt`, it counts.
3. Otherwise the whole screen is scanned for a reels keyword, and it only counts if the scrolled
   view is large (75% of the screen). This stops comment sheets and feed carousels from counting.

When a limit is hit, a full-screen "Take a break" overlay appears (an accessibility overlay, so no
"display over other apps" permission is needed). It disappears when you leave the reels screen,
so the rest of the app stays usable.

## Build (no local setup needed)

Push to GitHub. `.github/workflows/build-apk.yml` builds a release APK and attaches it to a
Release. On your phone, open `https://github.com/<you>/doompal/releases/latest` and download
`app-release.apk`.

The `android/` folder is generated during each build (`flutter create`), then
`tools/apply_overlay.py` adds the Kotlin code and resources from `android_overlay/`.

### Signing key

`android_overlay/debug.keystore` is a fixed debug key (password `android`), so every build is
signed the same way and installs as an update without losing your data. The workflow fails if
the APK is signed with any other key. This is fine for a personal, sideloaded app. If you ever
publish to the Play Store, make a private release key instead.

### Building locally (optional)

```
flutter create --project-name doompal --org io.doompal --platforms android /tmp/scaffold
cp -r /tmp/scaffold/android ./android
python tools/apply_overlay.py
cp android_overlay/debug.keystore ~/.android/debug.keystore   # only if you want the same key
flutter pub get
flutter run
```

## First run

1. Install the APK (allow "install unknown apps" for your browser or file manager).
2. Open DoomPal, tap **Open Accessibility settings**, find DoomPal, turn it on.
   On Android 13+, if the switch is greyed out: tap it once and close the popup, then open
   App info for DoomPal, tap the three dots, choose **Allow restricted settings**, and try again.
3. Set battery usage to **Unrestricted** so Android does not stop the service.

## Tuning detection

1. Limits tab > turn on **Detection log**.
2. Swipe through some reels, then open **View detection log** and tap copy.
3. Each line shows `src=` (the view that scrolled), `h=` (its share of the screen height),
   whether it matched, and sample view ids. Add the right keyword in
   `android_overlay/kotlin/Targets.kt`.

Note: inside Instagram's code, "reel" means Stories and "clips" means Reels.

**Count every scroll (lenient)** is a stopgap that counts any vertical scroll in the four apps.

## License

MIT
