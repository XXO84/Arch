#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS="$ROOT/apklab/reports"
SMOKE="$ROOT/apklab/smoke-app"
APK_URL="${1:-}"
PACKAGE=""
ACTIVITY=""
PID=""
mkdir -p "$REPORTS"
rm -f "$REPORTS"/*

capture_reports() {
  set +e
  adb devices -l > "$REPORTS/adb-devices.txt" 2>&1
  adb shell getprop > "$REPORTS/getprop.txt" 2>&1
  adb logcat -d -v threadtime > "$REPORTS/logcat.txt" 2>&1
  adb exec-out screencap -p > "$REPORTS/screenshot.png" 2>/dev/null
  if [[ -n "$PACKAGE" ]]; then
    adb shell dumpsys package "$PACKAGE" > "$REPORTS/package.txt" 2>&1
    adb shell dumpsys meminfo "$PACKAGE" > "$REPORTS/meminfo.txt" 2>&1
    adb shell dumpsys gfxinfo "$PACKAGE" > "$REPORTS/gfxinfo.txt" 2>&1
    adb shell dumpsys activity activities > "$REPORTS/activities.txt" 2>&1
  fi
  {
    echo "=== Java ==="
    java -version
    echo "=== Gradle ==="
    gradle --version
    echo "=== ADB ==="
    adb version
    echo "=== Emulator ==="
    emulator -version
    echo "=== /dev/kvm ==="
    ls -l /dev/kvm 2>&1 || true
  } > "$REPORTS/environment.txt" 2>&1
  set -e
}
trap capture_reports EXIT

adb wait-for-device
BOOT="$(adb shell getprop sys.boot_completed | tr -d '\r')"
[[ "$BOOT" == "1" ]] || { echo "Android did not reach sys.boot_completed=1" >&2; exit 20; }

adb logcat -c

if [[ -n "$APK_URL" ]]; then
  APK="$REPORTS/input.apk"
  curl --fail --location --retry 3 --retry-delay 2 "$APK_URL" -o "$APK"
else
  (
    cd "$SMOKE"
    gradle --no-daemon :app:assembleDebug
  )
  APK="$SMOKE/app/build/outputs/apk/debug/app-debug.apk"
fi

[[ -s "$APK" ]] || { echo "APK missing or empty: $APK" >&2; exit 21; }
sha256sum "$APK" > "$REPORTS/apk.sha256"

AAPT="$(command -v aapt || true)"
if [[ -z "$AAPT" && -n "${ANDROID_HOME:-}" ]]; then
  AAPT="$(find "$ANDROID_HOME/build-tools" -type f -name aapt 2>/dev/null | sort -V | tail -n 1)"
fi
[[ -x "$AAPT" ]] || { echo "aapt not found" >&2; exit 22; }

BADGING="$REPORTS/aapt-badging.txt"
"$AAPT" dump badging "$APK" | tee "$BADGING"
PACKAGE="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" "$BADGING" | head -n 1)"
ACTIVITY="$(sed -n "s/^launchable-activity: name='\([^']*\)'.*/\1/p" "$BADGING" | head -n 1)"
[[ -n "$PACKAGE" ]] || { echo "Could not determine package name" >&2; exit 23; }

adb install -r -t "$APK" | tee "$REPORTS/install.txt"

if [[ -n "$ACTIVITY" ]]; then
  adb shell am force-stop "$PACKAGE"
  adb shell am start -W -n "$PACKAGE/$ACTIVITY" | tee "$REPORTS/start.txt"
  sleep 3
  PID="$(adb shell pidof "$PACKAGE" | tr -d '\r' || true)"
  [[ -n "$PID" ]] || { echo "Package installed but launch process is not running: $PACKAGE" >&2; exit 24; }
else
  echo "No launchable activity; install-only verification completed." | tee "$REPORTS/start.txt"
fi

cat > "$REPORTS/result.json" <<EOF
{
  "status": "PASS",
  "boot_completed": "$BOOT",
  "api_level": "$(adb shell getprop ro.build.version.sdk | tr -d '\r')",
  "android_release": "$(adb shell getprop ro.build.version.release | tr -d '\r')",
  "package": "$PACKAGE",
  "activity": "$ACTIVITY",
  "pid": "$PID"
}
EOF

cat > "$REPORTS/REPORT.md" <<EOF
# APKLab Android Runtime Report

- Status: **PASS**
- sys.boot_completed: **$BOOT**
- Android API: **$(adb shell getprop ro.build.version.sdk | tr -d '\r')**
- Android release: **$(adb shell getprop ro.build.version.release | tr -d '\r')**
- Package: **$PACKAGE**
- Launch activity: **${ACTIVITY:-none}**
- PID after launch: **${PID:-n/a}**
- APK SHA-256: **$(cut -d' ' -f1 "$REPORTS/apk.sha256")**

Collected diagnostics: ADB device list, build properties, logcat, package/activity/memory/graphics dumps, environment versions, APK metadata and screenshot.
EOF

capture_reports
trap - EXIT
cat "$REPORTS/REPORT.md"
