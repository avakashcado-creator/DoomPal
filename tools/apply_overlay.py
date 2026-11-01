"""Applies DoomPal's native Android code on top of a freshly generated Flutter android/ folder."""
import pathlib
import shutil
import sys

root = pathlib.Path(__file__).resolve().parent.parent
android = root / "android"
overlay = root / "android_overlay"
main_dir = android / "app" / "src" / "main"
manifest = main_dir / "AndroidManifest.xml"

if not manifest.exists():
    sys.exit("android/ scaffold missing. Run `flutter create` first (see README).")

SERVICE = """
        <service
            android:name=".ReelAccessibilityService"
            android:exported="true"
            android:label="DoomPal"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_service_config" />
        </service>
        <activity
            android:name=".GuestPassActivity"
            android:exported="false"
            android:excludeFromRecents="true"
            android:taskAffinity=""
            android:theme="@android:style/Theme.Translucent.NoTitleBar" />
"""

SHARE_FILTERS = """
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
"""

text = manifest.read_text(encoding="utf-8")
if "USE_BIOMETRIC" not in text:
    import re
    m = re.search(r"<manifest[^>]*>", text)
    if not m:
        sys.exit("Unexpected manifest: no <manifest> tag found.")
    perm = '\n    <uses-permission android:name="android.permission.USE_BIOMETRIC" />'
    text = text[:m.end()] + perm + text[m.end():]
if "ReelAccessibilityService" not in text:
    if "</application>" not in text:
        sys.exit("Unexpected manifest: no </application> tag found.")
    text = text.replace("</application>", SERVICE + "    </application>", 1)
if "android.intent.action.SEND" not in text:
    if "</activity>" not in text:
        sys.exit("Unexpected manifest: no </activity> tag found.")
    # the first activity in the template is MainActivity
    text = text.replace("</activity>", SHARE_FILTERS + "        </activity>", 1)
text = text.replace('android:label="doompal"', 'android:label="DoomPal"')
manifest.write_text(text, encoding="utf-8")

# Replace whatever MainActivity the template made with ours
for old in main_dir.rglob("MainActivity.*"):
    old.unlink()
kotlin_dir = main_dir / "kotlin" / "io" / "doompal" / "doompal"
kotlin_dir.mkdir(parents=True, exist_ok=True)
for f in (overlay / "kotlin").glob("*.kt"):
    shutil.copy(f, kotlin_dir / f.name)

# Resources (accessibility config + strings)
shutil.copytree(overlay / "res", main_dir / "res", dirs_exist_ok=True)

print("DoomPal overlay applied.")
