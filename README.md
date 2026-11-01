# DoomPal

A free, open-source reel counter and blocker for Android. Counts how many reels you scroll in
Instagram, YouTube Shorts, Facebook and Snapchat, keeps your full history for free, and blocks
reels after your daily limit.

- No accounts, no ads, no paywalls, no internet permission. Everything stays on your phone.
- Per-app and total daily limits, "block completely" mode, hard mode (no snooze).
- Unlimited history with CSV export.
- Built-in detection log for tuning when apps change their screens.

## Features

- Counts Shorts and Reels live (YouTube Shorts and Instagram Reels by default; Facebook and Snapchat optional).
- **Strict by default:** a daily total limit of 50, quiet hours from 23:00 to 06:00, one beg a day.
- **The lock:** stricter changes apply at once, looser ones (a higher limit, turning something off) wait a
  cooldown you choose, 24 hours to start. A 20 minute setup window after you accept the terms lets you tune
  things first. Deleting history keeps today's numbers, so it can't be used to reset a limit.
- **Doomy coach:** learns on the phone from the last 7 days. Tightens limits (up to 50%), lengthens the joke
  ads and cuts begs when you keep hitting limits or begging. Eases back toward your own limit when you do
  well. Never looser than the limit you set. It also learns your danger hours and checks in more often then.
- **Guest pass:** for someone else (like a parent looking up a recipe). A fingerprint saved on the phone, then
  Doomy watches the guest's first 10 swipes and cancels the pass if they scroll like the owner. See the
  limits of this below.
- **Health:** an eye break every 20 minutes of scrolling, and quiet hours so sleep wins.
- Estimated time spent, an unlimited history with CSV export, and your own pictures on Doomy's memes.
- Free, no accounts, no ads, no internet permission.

### How reliable is the guest pass?

Honestly, it's a speed bump, not a lock. Android's fingerprint prompt only says yes or no, never whose
finger it was. The scroll-style check uses three timing numbers (pause between reels, swipe duration,
scroll events per swipe). In a simulation with made-up styles it caught an owner scrolling normally and let
through a guest with a clearly different pace, but it also cancelled a guest who happens to scroll like
the owner, and an owner who deliberately scrolls differently for 10 swipes gets through. Nothing in the
app can stop you turning off Accessibility, uninstalling, or changing the phone's clock either.

### Permissions

Accessibility (to count and block) and the fingerprint prompt (USE_BIOMETRIC, for the guest pass). There is
no internet permission, so the app cannot send anything anywhere.

## Doomy

Doomy is DoomPal's mascot. He counts your reels and roasts you about them in Gen Alpha.

- A big live counter (with Doomy's face, which changes as you near your limit) sits at the top of the screen while you scroll Shorts.
- He checks in when you open reels ("boi boi, no reels? why u scrolling").
- At your limit he tells you to pack it up. You can beg for a few more, but you have to sit
  through a fake, unskippable joke ad first, and every beg makes the next ad longer.
- The Doomy tab is a chat: ask how bad today is, get roasted, or ask for a meme.

The ads are jokes made by the app. There are no real ads, no ad network, and no internet access.

### Your own pictures and stickers

In the Rules tab, "Use my own pictures" lets you add pictures, GIFs and stickers three ways:

- **From gallery:** Android's photo picker. You choose, and the app only gets what you chose.
- **From files:** the file picker, for things like `.webp` stickers saved to Downloads.
- **Share:** DoomPal appears in other apps' Share menu for images. Share a sticker to DoomPal and
  it lands in your pictures.

DoomPal keeps private copies inside the app on your phone. Doomy puts captions on them ("ME AFTER
30 SHORTS") and uses them on the Today screen, in the chat and in the joke ads. Nothing is uploaded
and nothing is stored in this repository. DoomPal has no internet access, so it cannot browse
Sticker.ly or any other catalog. Until you add some, Doomy uses his own art.

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
