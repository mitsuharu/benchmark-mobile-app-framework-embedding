#!/bin/bash
#
# Lints the Swift sources with swift-format, which ships with Xcode — no extra
# tooling to install. Pass --fix to rewrite the files in place.
#
#   ./scripts/swift-format.sh
#   ./scripts/swift-format.sh --fix

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Only tracked files: everything generated (expo prebuild output, Flutter's
# ephemeral projects, DerivedData) is ignored by git, so this is exactly the
# hand-written Swift.
SOURCES=()
while IFS= read -r file; do
  SOURCES+=("$file")
done < <(git ls-files '*.swift')

if [[ ${#SOURCES[@]} -eq 0 ]]; then
  echo "swift-format: no Swift sources"
  exit 0
fi

if [[ "${1:-}" == "--fix" ]]; then
  xcrun swift-format format --in-place "${SOURCES[@]}"
  echo "swift-format: formatted ${#SOURCES[@]} files"
else
  xcrun swift-format lint --strict "${SOURCES[@]}"
  echo "swift-format: no issues in ${#SOURCES[@]} files"
fi
