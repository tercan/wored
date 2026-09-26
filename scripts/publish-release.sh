#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
version=${1:?Usage: GH_REPO=owner/repo bash scripts/publish-release.sh X.Y.Z}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid release version\n' >&2; exit 1; }
tag="v$version"
repo=${GH_REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}
commit=$(git rev-parse "$tag^{commit}")
[[ "$commit" == "$(git rev-parse HEAD)" ]] || { printf 'Check out the release tag before publishing\n' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { printf 'Publishing requires a clean working tree\n' >&2; exit 1; }
output="$root/dist/releases/$version"
python3 -c 'import json,sys; info=json.load(open(sys.argv[1])); assert info["version"]==sys.argv[2] and info["commit"]==sys.argv[3] and info["clean"] is True, "Packages must come from the clean release commit"' \
    "$output/BUILD_INFO.json" "$version" "$commit"
(
    cd "$output"
    shasum -a 256 -c SHA256SUMS.txt
)

mkdir -p documents
notes="$root/documents/release-notes-$version.md"
awk -v version="$version" '
    index($0, "## [" version "] - ") == 1 { found=1; next }
    found && /^## \[/ { exit }
    found { print }
' CHANGELOG.md > "$notes"
[[ -s "$notes" ]] || { printf 'Missing changelog section\n' >&2; exit 1; }
minimum_macos=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["minimumMacOS"])' "$output/BUILD_INFO.json")
printf '\n## İndirme ve Kurulum\n\nApple Silicon (arm64), macOS %s veya üzeri. DMG dosyasını açıp Wored uygulamasını Applications bağlantısına sürükleyin veya ZIP içindeki Wored.app dosyasını Uygulamalar klasörüne taşıyın.\n\nPaketler ad-hoc imzalıdır; Developer ID imzası ve Apple notarization içermez. macOS ilk açılışta güvenlik uyarısı gösterebilir. SHA256SUMS.txt bütünlük doğrulaması, BUILD_INFO.json kaynak commit bilgisi içerir.\n' "$minimum_macos" >> "$notes"

if ! gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
    gh release create "$tag" --repo "$repo" --verify-tag --draft --title "Wored $version" --notes-file "$notes"
fi
gh release upload "$tag" --repo "$repo" --clobber \
    "$output/Wored-$version-macOS-arm64.zip" "$output/Wored-$version-macOS-arm64.dmg" \
    "$output/SHA256SUMS.txt" "$output/BUILD_INFO.json"

latest=$(gh release list --repo "$repo" --limit 100 --exclude-drafts --json tagName | \
    python3 -c 'import json,re,sys; versions=[tuple(map(int,r["tagName"][1:].split("."))) for r in json.load(sys.stdin) if re.fullmatch(r"v\d+\.\d+\.\d+",r["tagName"])]; print("true" if tuple(map(int,sys.argv[1].split("."))) >= max(versions,default=(0,0,0)) else "false")' "$version")
gh release edit "$tag" --repo "$repo" --title "Wored $version" --notes-file "$notes" --draft=false --latest="$latest"
gh release view "$tag" --repo "$repo" --json url,tagName,isDraft,assets
