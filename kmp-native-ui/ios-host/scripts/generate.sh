#!/bin/bash
#
# Generates HostApp.xcodeproj, linking the RepoSearchKit XCFramework of one
# build type from ../shared/build/XCFrameworks/<build>/.
#
#   ./scripts/generate.sh           # release: assembleRepoSearchKitReleaseXCFramework
#   ./scripts/generate.sh debug     # debug:   assembleRepoSearchKitDebugXCFramework

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

export KMP_FRAMEWORK_BUILD="${1:-release}"

framework="../shared/build/XCFrameworks/$KMP_FRAMEWORK_BUILD/RepoSearchKit.xcframework"
if [[ ! -d "$framework" ]]; then
  task="assembleRepoSearchKit$(tr '[:lower:]' '[:upper:]' <<< "${KMP_FRAMEWORK_BUILD:0:1}")${KMP_FRAMEWORK_BUILD:1}XCFramework"
  echo "$framework is missing. In ../shared run:" >&2
  echo "  ./gradlew $task" >&2
  exit 1
fi

xcodegen generate
