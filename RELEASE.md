# Release guide

## Verified toolchain

| Tool | Version used to build this repo |
|---|---|
| Flutter | 3.35.7 stable |
| JDK | 21 (AGP 8.9 needs 17+) |
| Android SDK | platform 36, build-tools 35.0.0, NDK 27.0.12077973 |

## Verify before building

```bash
flutter analyze                  # must be clean
flutter test                     # 34 tests
python3 tool/generate_icons.py   # branding is byte-reproducible
```

## Release

**1. Create the upload keystore (once):**

```bash
./tool/make_keystore.sh
```

Writes `android/app/upload-keystore.jks` and `android/key.properties`, both
gitignored. **Back them up.** Losing them means you can never update the app
under the same Play listing.

Without them the release build still compiles but falls back to *debug*
signing, and **Play will reject the upload**.

**2. Replace the AdMob test IDs:**

- `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID`
- `lib/services/ads.dart` → the four unit-ID constants

**3. Build:**

```bash
flutter build appbundle --release   # -> app-release.aab, for Play
flutter build apk --release         # -> app-release.apk, for sideload
```

Verified sizes: **APK 18.7 MB** (arm64, R8), **AAB 45.1 MB**.

## Building on a low-memory machine

`android/gradle.properties` is tuned for 2 GB / 2 cores: 1100 MB heap, serial
GC, one worker, Kotlin in-process. Three failure modes were hit and fixed while
building this repo — check these first:

**1. `Gradle build daemon disappeared unexpectedly`** — the kernel OOM-killed
it. The machine needs swap:

```bash
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
```

**2. `Could not read workspace metadata from .../transforms/...`** — corrupt
Gradle cache. Delete `$GRADLE_USER_HOME` and rebuild.

**3. NDK "did not have a source.properties file"** — a half-extracted NDK from
an interrupted download. Remove and reinstall:

```bash
rm -rf $ANDROID_HOME/ndk && sdkmanager "ndk;27.0.12077973"
```

On a larger machine, raise the heap:

```properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g
org.gradle.workers.max=4
org.gradle.parallel=true
```

## Pre-launch checklist

- [ ] Real AdMob IDs in place
- [ ] `remove_ads` product created in Play Console (matches `IapService.productId`)
- [ ] Keystore generated and backed up
- [ ] Listing uses `assets/branding/play_icon_512.png` and `play_feature_1024x500.png`
- [ ] Screenshots from a real device
- [ ] Privacy policy URL live (the app uses an advertising ID)
- [ ] Data-safety form: declare the ads SDK collects an advertising ID
- [ ] Tested on a physical low-end device
- [ ] **Tested with an actual older adult**

## Do not

- Claim cognitive or medical benefits. Lumosity paid a **$2M FTC settlement**
  for advertising that brain games reduce age-related decline.
- Buy testers or installs. One policy strike can terminate the account and
  every app on it.
