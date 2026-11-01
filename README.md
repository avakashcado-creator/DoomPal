# DoomPal

A free, open-source reel counter and blocker for Android. Counts how many reels you scroll in
Instagram, YouTube Shorts, Facebook and Snapchat, keeps your full history for free, and blocks
reels after your daily limit.

- No accounts, no ads, no paywalls, no internet permission. Everything stays on your phone.
- Per-app and total daily limits, "block completely" mode, hard mode (no snooze).
- Unlimited history with CSV export.
- Built-in detection log for tuning when apps change their screens.

## Features

- Counts Shorts/Reels live (YouTube Shorts and Instagram Reels on by default; Facebook and Snapchat optional).
- Estimated time spent, per day and per app (measured from the gaps between swipes).
- Daily total limit and per-app limits. "Block completely" mode.
- Break-the-cycle tools: nudge popup every N reels, hard mode, a cap on snoozes per day,
  quiet hours (for example 23:00 to 06:00), and a "take a break" screen with ideas of what to do instead.
- Brain meter that drains as you approach your limit, and a streak of days within your limit.
- Unlimited history with CSV export. All free, no accounts, no internet permission.

## Doomy

Doomy is DoomPal's mascot. He counts your reels and roasts you about them.

- A live counter bubble sits at the top of the screen while you scroll Shorts.
- He checks in when you open reels ("boi boi, no reels? why u scrolling").
- At your limit he tells you to pack it up. You can beg for a few more, but you have to sit
  through a fake, unskippable joke ad first, and every beg makes the next ad longer.
- The Doomy tab is a chat: ask how bad today is, get roasted, or ask for a meme.

The ads are jokes made by the app. There are no real ads, no ad network, and no internet access.

### Adding memes, GIFs and stickers

No code needed. Upload images into these folders on GitHub and they appear in the next build:

- `assets/memes/` for finished memes, GIFs and stickers. Shown as they are.
- `assets/templates/` for plain reaction photos. Doomy writes captions on them ("ME AFTER 40 SHORTS").

PNG, JPG, GIF and WebP all work. GIFs animate. Remember this repository is public, so anything
you upload here can be seen by others.

## How it works

An Android Accessibility Service listens only to the four apps (see
`android_overlay/res/xml/accessibility_service_config.xml`). A reel is counted when a vertical
swipe starts on the reels screen:

1. A burst of scroll events is treated as one swipe (400 ms quiet gap, max one count per 700 ms).
2. If the scrolled view's id matches a reels keyword in `Targets.kt`, it counts.
3. Apps without "strict" mode (Instagram, Facebook, Snapchat) can also count when the screen has a
   reels keyword and the scrolled view is large (75% of the screen height).
4. YouTube is strict: only the Shorts pager itself counts, so scrolling comments never counts.
5. Visible sponsored items ("Ad", "Sponsored") are skipped, at most 3 in a row.

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
