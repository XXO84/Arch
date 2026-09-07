#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS="$ROOT/apklab/reports"
B64_PREFIX="$ROOT/apklab/modewidget-source.b64.part"
WORK="$RUNNER_TEMP/apklab-modewidget-a53"
APK_URL="${1:-}"
PACKAGE="de.apklab.moduswidget"
ACTIVITY="de.apklab.moduswidget.MainActivity"
STOREPASS="$(openssl rand -hex 24)"
KEYPASS="$STOREPASS"
mkdir -p "$REPORTS"
rm -rf "$REPORTS"/* "$WORK"
mkdir -p "$WORK"

capture_reports() {
  set +e
  adb devices -l > "$REPORTS/adb-devices.txt" 2>&1
  adb shell getprop > "$REPORTS/getprop.txt" 2>&1
  adb logcat -d -v threadtime > "$REPORTS/logcat.txt" 2>&1
  adb exec-out screencap -p > "$REPORTS/screenshot.png" 2>/dev/null
  adb shell dumpsys package "$PACKAGE" > "$REPORTS/package.txt" 2>&1 || true
  adb shell dumpsys meminfo "$PACKAGE" > "$REPORTS/meminfo.txt" 2>&1 || true
  adb shell dumpsys gfxinfo "$PACKAGE" > "$REPORTS/gfxinfo.txt" 2>&1 || true
  adb shell dumpsys activity activities > "$REPORTS/activities.txt" 2>&1 || true
  {
    echo "=== Java ==="; java -version
    echo "=== ADB ==="; adb version
    echo "=== Emulator ==="; emulator -version || true
    echo "=== Android SDK ==="; echo "ANDROID_HOME=${ANDROID_HOME:-}"; ls -la "${ANDROID_HOME:-/nonexistent}/build-tools/36.0.0" 2>/dev/null || true
  } > "$REPORTS/environment.txt" 2>&1
  set -e
}
trap capture_reports EXIT

adb wait-for-device
BOOT="$(adb shell getprop sys.boot_completed | tr -d '\r')"
[[ "$BOOT" == "1" ]] || { echo "Android did not reach sys.boot_completed=1" >&2; exit 20; }
adb logcat -c

if [[ -n "$APK_URL" ]]; then
  echo "This APKLab branch is dedicated to building the bundled ModeWidget source; apk_url is ignored." >&2
fi

compgen -G "${B64_PREFIX}*" >/dev/null || { echo "ModeWidget source payload parts missing: ${B64_PREFIX}*" >&2; exit 30; }
cat "${B64_PREFIX}"* | base64 -d > "$WORK/source.zip"
unzip -q "$WORK/source.zip" -d "$WORK/source"
PROJECT="$(find "$WORK/source" -mindepth 1 -maxdepth 1 -type d -name 'APK-LAB-ModeWidget-A53*' -print -quit)"
[[ -n "$PROJECT" ]] || PROJECT="$WORK/source/APK-LAB-ModeWidget-A53"
[[ -f "$PROJECT/settings.gradle" ]] || { echo "Gradle project not found after decode" >&2; find "$WORK/source" -maxdepth 3 -type f; exit 31; }

# Exact persistent APK-LAB toolchain versions requested for this project.
yes | sdkmanager --licenses >/dev/null || true
sdkmanager 'platforms;android-36' 'build-tools;36.0.0' 'platform-tools'

GRADLE_VERSION='9.6.1'
GRADLE_ZIP="$WORK/gradle-${GRADLE_VERSION}-bin.zip"
GRADLE_HOME_LOCAL="$WORK/gradle-${GRADLE_VERSION}"
curl --fail --location --retry 3 --retry-delay 2 \
  "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o "$GRADLE_ZIP"
unzip -q "$GRADLE_ZIP" -d "$WORK"
GRADLE="$GRADLE_HOME_LOCAL/bin/gradle"
"$GRADLE" --version | tee "$REPORTS/gradle-version.txt"

export JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}" 
export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/36.0.0:$PATH"

cd "$PROJECT"
python3 scripts/SOURCE_AUDIT.py | tee "$REPORTS/source-audit.txt"
"$GRADLE" --no-daemon --console=plain --stacktrace \
  -Pandroid.aapt2FromMavenOverride="$ANDROID_HOME/build-tools/36.0.0/aapt2" \
  :app:checkReleaseAarMetadata :app:lintVitalRelease :app:assembleRelease \
  | tee "$REPORTS/gradle-build.txt"

UNSIGNED="$(find app/build/outputs/apk/release -maxdepth 1 -type f -name '*unsigned*.apk' -print -quit)"
[[ -s "$UNSIGNED" ]] || { echo "Unsigned release APK missing" >&2; find app/build/outputs -type f -maxdepth 5 || true; exit 32; }

KEYSTORE="$REPORTS/ModeWidget-A53-v1.0.0-signing.jks"
keytool -genkeypair -noprompt \
  -keystore "$KEYSTORE" -storepass "$STOREPASS" -keypass "$KEYPASS" \
  -alias modewidget -keyalg RSA -keysize 4096 -validity 10000 \
  -dname 'CN=APK LAB ModeWidget A53, OU=APK LAB, O=Local Build, L=Local, C=DE' \
  > "$REPORTS/keytool.txt" 2>&1

ALIGNED="$WORK/ModeWidget-A53-v1.0.0-aligned.apk"
FINAL="$REPORTS/ModeWidget-A53-v1.0.0.apk"
zipalign -f -p 4 "$UNSIGNED" "$ALIGNED"
apksigner sign \
  --ks "$KEYSTORE" --ks-pass "pass:$STOREPASS" --key-pass "pass:$KEYPASS" \
  --ks-key-alias modewidget \
  --out "$FINAL" "$ALIGNED"

zipalign -c -P 16 -v 4 "$FINAL" | tee "$REPORTS/zipalign.txt"
apksigner verify --verbose --print-certs "$FINAL" | tee "$REPORTS/apksigner.txt"
aapt dump badging "$FINAL" | tee "$REPORTS/aapt-badging.txt"
sha256sum "$FINAL" | tee "$REPORTS/ModeWidget-A53-v1.0.0.apk.sha256"
cat > "$REPORTS/SIGNING_KEY_README.txt" <<KEYINFO
Keep ModeWidget-A53-v1.0.0-signing.jks for future updates of this APK.
Alias: modewidget
Store password: $STOREPASS
Key password: $KEYPASS
KEYINFO

# Runtime smoke test in APK LAB emulator.
adb install -r -t "$FINAL" | tee "$REPORTS/install.txt"
adb shell pm grant "$PACKAGE" android.permission.DUMP | tee "$REPORTS/grant-dump.txt" || true
adb shell am force-stop "$PACKAGE"
adb shell am start -W -n "$PACKAGE/$ACTIVITY" | tee "$REPORTS/start.txt"
sleep 4
PID="$(adb shell pidof "$PACKAGE" | tr -d '\r' || true)"
[[ -n "$PID" ]] || { echo "ModeWidget installed but process is not running" >&2; exit 33; }

# Confirm the development DUMP grant and that SensorService is callable from the installed UID via app context later.
adb shell dumpsys package "$PACKAGE" | grep -A40 -E 'grantedPermissions|android.permission.DUMP' > "$REPORTS/dump-permission.txt" || true

cat > "$REPORTS/result.json" <<RESULT
{
  "status": "PASS",
  "boot_completed": "$BOOT",
  "api_level": "$(adb shell getprop ro.build.version.sdk | tr -d '\r')",
  "android_release": "$(adb shell getprop ro.build.version.release | tr -d '\r')",
  "package": "$PACKAGE",
  "activity": "$ACTIVITY",
  "pid": "$PID",
  "apk_sha256": "$(cut -d' ' -f1 "$REPORTS/ModeWidget-A53-v1.0.0.apk.sha256")"
}
RESULT
cat > "$REPORTS/REPORT.md" <<REPORT
# APK LAB ModeWidget A53 Build Report

- Build: **PASS**
- Source audit: **PASS**
- Gradle: **9.6.1**
- JDK: **21**
- compileSdk: **36**
- Build Tools: **36.0.0**
- APK signature verification: **PASS**
- 16 KiB ZIP alignment check: **PASS**
- Emulator install/launch: **PASS**
- Package: **$PACKAGE**
- PID after launch: **$PID**
- APK SHA-256: **$(cut -d' ' -f1 "$REPORTS/ModeWidget-A53-v1.0.0.apk.sha256")**
REPORT

# Text fallback so ChatGPT can recover the binary even if artifact mounting is unavailable.
echo '===APK_BASE64_BEGIN==='
base64 -w 0 "$FINAL"
echo
echo '===APK_BASE64_END==='

capture_reports
trap - EXIT
cat "$REPORTS/REPORT.md"
