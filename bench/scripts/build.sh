#!/bin/bash
#
# Builds the benchmark build of one implementation into bench/artifacts: a
# release build that sends its searches to bench/mock-server.
#
#   ./scripts/build.sh <native|kmp|flutter|expo> <ios|android>
#
# iOS produces an app for the simulator, Android an APK signed with the debug
# key (R8 enabled), which is what run.mjs installs.

set -euo pipefail

FRAMEWORK="${1:?framework: native, kmp, flutter or expo}"
PLATFORM="${2:?platform: ios or android}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/bench/artifacts/$FRAMEWORK/$PLATFORM"

# The iOS simulator shares the host's network. The Android emulator reaches
# the mock server on its own loopback too: run.mjs sets up `adb reverse`,
# because going through the emulator's NAT (10.0.2.2) took 0.6-1 s a request.
IOS_API_BASE_URL="http://127.0.0.1:8787"
ANDROID_API_BASE_URL="http://127.0.0.1:8787"

build_ios_host() {
  local host="$1"
  # How the project is generated; Flutter's host picks a framework build mode.
  local generate="${2:-xcodegen generate --quiet}"
  local settings=(
    -project "$host/HostApp.xcodeproj"
    -scheme HostApp
    -configuration Release
    -sdk iphonesimulator
    # Every host app is called HostApp and several frameworks are called
    # RepoSearchKit. With a custom Build Location in Xcode's settings (which
    # -derivedDataPath does not override), all of them would land in one
    # products directory and link against each other's builds. Explicit
    # SYMROOT / OBJROOT keep each host's build to itself.
    SYMROOT="$host/build/Products"
    OBJROOT="$host/build/Intermediates"
  )

  (cd "$host" && $generate)
  xcodebuild build "${settings[@]}" \
    -destination 'generic/platform=iOS Simulator' \
    BENCH_API_BASE_URL="$IOS_API_BASE_URL" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

  local dir
  dir="$(xcodebuild "${settings[@]}" -showBuildSettings 2>/dev/null |
    sed -n 's/^ *TARGET_BUILD_DIR = //p' | head -1)"

  rm -rf "$OUT"
  mkdir -p "$OUT"
  ditto "$dir/HostApp.app" "$OUT/HostApp.app"
}

build_android_host() {
  local host="$1"

  (cd "$host" && ./gradlew assembleRelease -PbenchApiBaseUrl="$ANDROID_API_BASE_URL" --quiet)

  rm -rf "$OUT"
  mkdir -p "$OUT"
  cp "$host/app/build/outputs/apk/release/app-release.apk" "$OUT/app-release.apk"
}

case "$FRAMEWORK/$PLATFORM" in
  native/ios)
    build_ios_host "$ROOT/native/ios-host"
    ;;
  native/android)
    build_android_host "$ROOT/native/android-host"
    ;;
  kmp/ios)
    (cd "$ROOT/kmp/shared" && ./gradlew assembleRepoSearchKitReleaseXCFramework --quiet)
    build_ios_host "$ROOT/kmp/ios-host"
    ;;
  kmp/android)
    (cd "$ROOT/kmp/shared" && ./gradlew publishToHostApp --quiet)
    build_android_host "$ROOT/kmp/android-host"
    ;;
  flutter/ios)
    # Release (AOT) Flutter has no Dart code in its simulator slice, so the
    # simulator can only run the Debug (JIT) frameworks. The host app itself
    # is still built for release. See flutter/README.md.
    (cd "$ROOT/flutter/flutter_module" &&
      fvm flutter build ios-framework --debug --no-profile --no-release --no-codesign --output=../ios-host/Flutter)
    build_ios_host "$ROOT/flutter/ios-host" "./scripts/generate.sh Debug"
    ;;
  flutter/android)
    (cd "$ROOT/flutter/flutter_module" &&
      fvm flutter build aar --no-debug --no-profile -o "$ROOT/flutter/android-host/local-repo")
    build_android_host "$ROOT/flutter/android-host"
    ;;
  expo/ios)
    (cd "$ROOT/expo/expo-app" && npm run prebuild:ios && npm run brownfield:ios)
    build_ios_host "$ROOT/expo/ios-host"
    ;;
  expo/android)
    (cd "$ROOT/expo/expo-app" && npm run prebuild:android && npm run brownfield:android)
    build_android_host "$ROOT/expo/android-host"
    ;;
  *)
    echo "No benchmark build for $FRAMEWORK/$PLATFORM yet" >&2
    exit 1
    ;;
esac

echo "Built $OUT"
