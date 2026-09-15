#!/bin/bash
#
# Generates HostApp.xcodeproj, embedding the Flutter frameworks of one build
# mode from Flutter/<mode>/ (the output of `flutter build ios-framework`).
#
#   ./scripts/generate.sh            # Release (AOT): devices, and CI's build check
#   ./scripts/generate.sh Debug      # Debug (JIT): the only mode that runs on the simulator
#
# Flutter's Release and Profile frameworks carry the AOT snapshot for devices
# only; their simulator slice has no Dart code, so a host linking them builds
# for the simulator but cannot run the screen there.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

export FLUTTER_BUILD_MODE="${1:-Release}"

if [[ ! -d "Flutter/$FLUTTER_BUILD_MODE" ]]; then
  echo "Flutter/$FLUTTER_BUILD_MODE is missing. In ../flutter_module run:" >&2
  echo "  fvm flutter build ios-framework --output=../ios-host/Flutter" >&2
  exit 1
fi

xcodegen generate
