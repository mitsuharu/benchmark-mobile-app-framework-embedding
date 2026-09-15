#!/bin/bash
#
# Generates HostApp.xcodeproj, using the Swift Package of one build
# configuration from ../expo-app/artifacts/RepoSearchKitPackage-<build>/.
#
#   ./scripts/generate.sh           # release: `npm run brownfield:ios`, JS bundled in
#   ./scripts/generate.sh debug     # debug:   `npm run brownfield:ios:debug`, JS from Metro
#
# expo-brownfield keeps only the package it built last, so build the one you
# generate for.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

export EXPO_PACKAGE_BUILD="${1:-release}"

package="../expo-app/artifacts/RepoSearchKitPackage-$EXPO_PACKAGE_BUILD"
if [[ ! -d "$package" ]]; then
  script="brownfield:ios"
  [[ "$EXPO_PACKAGE_BUILD" == "debug" ]] && script="brownfield:ios:debug"
  echo "$package is missing. In ../expo-app run:" >&2
  echo "  npm run $script" >&2
  exit 1
fi

xcodegen generate
