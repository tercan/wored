#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
work=$(mktemp -d "${TMPDIR:-/tmp}/wored-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT
sdk=$(xcrun --sdk macosx --show-sdk-path)

for test in SingleInstanceLock PanelFramePersistence; do
    xcrun swiftc -sdk "$sdk" -parse-as-library -module-cache-path "$work/modules" \
        "Services/$test.swift" "Tests/${test}Tests.swift" -o "$work/$test"
    "$work/$test"
done

xcrun swiftc -sdk "$sdk" -parse-as-library -default-isolation MainActor -module-cache-path "$work/modules" \
    App/WindowManager.swift Tests/WindowDockingTests.swift -o "$work/WindowDocking"
"$work/WindowDocking"
