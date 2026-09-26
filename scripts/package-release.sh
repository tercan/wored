#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
version=${1:?Usage: bash scripts/package-release.sh X.Y.Z}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid release version\n' >&2; exit 1; }
grep -Fxq "$version" README.md
grep -Fq "## [$version] - " CHANGELOG.md
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
bash scripts/test.sh

work=$(mktemp -d "${TMPDIR:-/tmp}/wored-release.XXXXXX")
trap 'rm -rf "$work"' EXIT
commit=$(git rev-parse HEAD)
clean=true
if [[ -n "$(git status --porcelain)" ]]; then clean=false; fi

xcodebuild -quiet -project wored.xcodeproj -scheme Wored -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$work/derived" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO ENABLE_HARDENED_RUNTIME=YES build

app="$work/derived/Build/Products/Release/Wored.app"
actual=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
minimum_macos=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$app/Contents/Info.plist")
[[ "$actual" == "$version" ]] || { printf 'Bundle version differs from requested release\n' >&2; exit 1; }
codesign --verify --deep --strict "$app"
lipo -verify_arch arm64 "$app/Contents/MacOS/Wored"

output="$root/dist/releases/$version"
mkdir -p "$output" "$work/dmg" "$work/current"
zip="Wored-$version-macOS-arm64.zip"
dmg="Wored-$version-macOS-arm64.dmg"
ditto -c -k --sequesterRsrc --keepParent "$app" "$output/$zip"
ditto "$app" "$work/dmg/Wored.app"
ln -s /Applications "$work/dmg/Applications"
hdiutil create -quiet -volname "Wored $version" -srcfolder "$work/dmg" -format UDZO -ov "$output/$dmg"
hdiutil verify "$output/$dmg"

printf '{"version":"%s","commit":"%s","clean":%s,"architecture":"arm64","minimumMacOS":"%s","signing":"ad-hoc","notarized":false}\n' \
    "$version" "$commit" "$clean" "$minimum_macos" > "$output/BUILD_INFO.json"
(
    cd "$output"
    shasum -a 256 "$zip" "$dmg" BUILD_INFO.json > SHA256SUMS.txt
    shasum -a 256 -c SHA256SUMS.txt
)

ditto -x -k "$output/$zip" "$work/unpacked"
codesign --verify --deep --strict "$work/unpacked/Wored.app"
ditto "$app" "$work/current/Wored.app"
previous=""
if [[ -e dist/Wored.app ]]; then
    previous=$(mktemp -d "$root/dist/.wored-previous.XXXXXX")
    mv dist/Wored.app "$previous/Wored.app"
fi
if ! mv "$work/current/Wored.app" dist/Wored.app; then
    if [[ -n "$previous" ]]; then mv "$previous/Wored.app" dist/Wored.app; fi
    exit 1
fi
codesign --verify --deep --strict dist/Wored.app
printf 'Release packages: %s\nCurrent application: %s/dist/Wored.app\n' "$output" "$root"
