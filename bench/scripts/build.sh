#!/bin/bash
#
# Builds the benchmark build of one implementation into
# bench/artifacts/<build>/<framework>/<platform>: a build that sends its
# searches to bench/mock-server.
#
#   ./scripts/build.sh <native|kmp|flutter|expo> <ios|android> [release|debug] [simulator|device]
#
# release (the default) is what the main results compare. debug builds every
# part the way a developer runs it day to day: Xcode's Debug configuration,
# Android's debug build type, the Kotlin/Native debug framework, Flutter in
# JIT mode, and React Native loading its JavaScript from Metro (start it with
# `npx expo start` in expo/expo-app before measuring).
#
# iOS produces an app for the simulator, Android an APK (the release one is
# signed with the debug key and shrunk by R8), which is what run.mjs installs.
#
# `device` builds iOS for a physical iPhone into <platform>-device/: signed
# with the team in BENCH_IOS_TEAM_ID, and searching the mock server on the
# Mac's LAN address (BENCH_IOS_DEVICE_API_BASE_URL overrides it), since an
# iPhone cannot reach the Mac's loopback. Flutter can then use its release
# (AOT) frameworks. Android devices run the same APK as the emulator.

set -euo pipefail

FRAMEWORK="${1:?framework: native, kmp, flutter or expo}"
PLATFORM="${2:?platform: ios or android}"
BUILD="${3:-release}"
TARGET="${4:-simulator}"
case "$BUILD" in
  release | debug) ;;
  *)
    echo "build: release or debug" >&2
    exit 1
    ;;
esac
case "$TARGET" in
  simulator | device) ;;
  *)
    echo "target: simulator or device" >&2
    exit 1
    ;;
esac

# Xcode configurations and Gradle tasks spell it capitalized.
CONFIG="$(tr '[:lower:]' '[:upper:]' <<< "${BUILD:0:1}")${BUILD:1}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/bench/artifacts/$BUILD/$FRAMEWORK/$PLATFORM"

# The iOS simulator shares the host's network. The Android emulator reaches
# the mock server on its own loopback too: run.mjs sets up `adb reverse`,
# because going through the emulator's NAT (10.0.2.2) took 0.6-1 s a request.
IOS_API_BASE_URL="http://127.0.0.1:8787"
ANDROID_API_BASE_URL="http://127.0.0.1:8787"

IOS_SDK=iphonesimulator
IOS_DESTINATION='generic/platform=iOS Simulator'
IOS_SIGNING=(CODE_SIGNING_ALLOWED=NO)
if [[ "$PLATFORM" == "ios" && "$TARGET" == "device" ]]; then
  : "${BENCH_IOS_TEAM_ID:?set BENCH_IOS_TEAM_ID to the Apple Developer team that signs device builds}"
  OUT="$OUT-device"
  IOS_SDK=iphoneos
  IOS_DESTINATION='generic/platform=iOS'
  IOS_SIGNING=(-allowProvisioningUpdates DEVELOPMENT_TEAM="$BENCH_IOS_TEAM_ID" CODE_SIGN_STYLE=Automatic)
  IOS_API_BASE_URL="${BENCH_IOS_DEVICE_API_BASE_URL:-http://$(ipconfig getifaddr en0):8787}"
fi

build_ios_host() {
  local host="$1"
  # How the project is generated; some hosts pick their framework's build.
  local generate="${2:-xcodegen generate --quiet}"
  local settings=(
    -project "$host/HostApp.xcodeproj"
    -scheme HostApp
    -configuration "$CONFIG"
    -sdk "$IOS_SDK"
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
    -destination "$IOS_DESTINATION" \
    BENCH_API_BASE_URL="$IOS_API_BASE_URL" \
    "${IOS_SIGNING[@]}" \
    -quiet

  local dir
  dir="$(xcodebuild "${settings[@]}" -showBuildSettings 2>/dev/null |
    sed -n 's/^ *TARGET_BUILD_DIR = //p' | head -1)"

  rm -rf "$OUT"
  mkdir -p "$OUT"
  ditto "$dir/HostApp.app" "$OUT/HostApp.app"
}

# expo-brownfield looks for its framework in ios/build/Build/Products, but a
# custom absolute Build Location in Xcode's settings puts every product
# elsewhere (and `prebuild --clean` removes ios/ each time). Point the
# expected directory at the custom one when that setting is in use.
link_custom_build_products() {
  local ios="$1"
  local style type products
  style="$(defaults read com.apple.dt.Xcode IDEBuildLocationStyle 2>/dev/null || true)"
  type="$(defaults read com.apple.dt.Xcode IDECustomBuildLocationType 2>/dev/null || true)"
  products="$(defaults read com.apple.dt.Xcode IDECustomBuildProductsPath 2>/dev/null || true)"
  if [[ "$style" == "Custom" && "$type" == "Absolute" && -n "$products" ]]; then
    mkdir -p "$ios/build/Build"
    ln -sfn "$products" "$ios/build/Build/Products"
  fi
}

build_android_host() {
  local host="$1"

  (cd "$host" && ./gradlew "assemble$CONFIG" -PbenchApiBaseUrl="$ANDROID_API_BASE_URL" --quiet)

  rm -rf "$OUT"
  mkdir -p "$OUT"
  cp "$host/app/build/outputs/apk/$BUILD/app-$BUILD.apk" "$OUT/app-$BUILD.apk"
}

case "$FRAMEWORK/$PLATFORM" in
  native/ios)
    build_ios_host "$ROOT/native/ios-host"
    ;;
  native/android)
    build_android_host "$ROOT/native/android-host"
    ;;
  kmp/ios)
    (cd "$ROOT/kmp/shared" && ./gradlew "assembleRepoSearchKit${CONFIG}XCFramework" --quiet)
    build_ios_host "$ROOT/kmp/ios-host" "./scripts/generate.sh $BUILD"
    ;;
  kmp/android)
    # The KMP Android library has a single variant, so both host builds use
    # the same library; only the host's build type differs.
    (cd "$ROOT/kmp/shared" && ./gradlew publishToHostApp --quiet)
    build_android_host "$ROOT/kmp/android-host"
    ;;
  flutter/ios)
    # Release (AOT) Flutter has no Dart code in its simulator slice, so the
    # simulator can only run the Debug (JIT) frameworks, whichever build the
    # host app is. See flutter/README.md. A device runs the matching mode.
    mode=Debug
    [[ "$TARGET" == "device" ]] && mode="$CONFIG"
    if [[ "$mode" == "Release" ]]; then
      modes=(--no-debug --no-profile --release)
    else
      modes=(--debug --no-profile --no-release)
    fi
    (cd "$ROOT/flutter/flutter_module" &&
      fvm flutter build ios-framework "${modes[@]}" --no-codesign --output=../ios-host/Flutter)
    build_ios_host "$ROOT/flutter/ios-host" "./scripts/generate.sh $mode"
    ;;
  flutter/android)
    if [[ "$BUILD" == "release" ]]; then
      modes=(--no-debug --no-profile)
    else
      modes=(--no-profile --no-release)
    fi
    (cd "$ROOT/flutter/flutter_module" &&
      fvm flutter build aar "${modes[@]}" -o "$ROOT/flutter/android-host/local-repo")
    build_android_host "$ROOT/flutter/android-host"
    ;;
  expo/ios)
    script="brownfield:ios"
    [[ "$BUILD" == "debug" ]] && script="brownfield:ios:debug"
    (cd "$ROOT/expo/expo-app" && npm run prebuild:ios)
    link_custom_build_products "$ROOT/expo/expo-app/ios"
    (cd "$ROOT/expo/expo-app" && npm run "$script")
    build_ios_host "$ROOT/expo/ios-host" "./scripts/generate.sh $BUILD"
    ;;
  expo/android)
    # Each build publishes only its own variant under the same coordinates,
    # so the library is rebuilt for every host build.
    script="brownfield:android"
    [[ "$BUILD" == "debug" ]] && script="brownfield:android:debug"
    (cd "$ROOT/expo/expo-app" && npm run prebuild:android && npm run "$script")
    build_android_host "$ROOT/expo/android-host"
    ;;
  *)
    echo "No benchmark build for $FRAMEWORK/$PLATFORM yet" >&2
    exit 1
    ;;
esac

echo "Built $OUT"
