#!/usr/bin/env bash
set -euo pipefail

commit="${1:?usage: refresh-overlay.sh VCPKG_COMMIT}"
readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly port_dir="$root_dir/overlay-ports/tesseract"
readonly source_url="https://raw.githubusercontent.com/microsoft/vcpkg/$commit/ports/tesseract"
readonly port_files=(
    fix-link-include-path.patch
    fix-msvc-training-tools.patch
    fix_static_link_icu.patch
    portfile.cmake
    target-curl.diff
    vcpkg.json
)

for port_file in "${port_files[@]}"; do
    curl --fail --location --retry 3 --output "$port_dir/$port_file" "$source_url/$port_file"
done

jq '
  .dependencies |= map(select(
    . != "curl" and . != "libarchive" and
    (type != "object" or (.name != "curl" and .name != "libarchive"))
  ))
' "$port_dir/vcpkg.json" > "$port_dir/vcpkg.json.tmp"
mv "$port_dir/vcpkg.json.tmp" "$port_dir/vcpkg.json"

perl -0pi -e 's/-DCMAKE_REQUIRE_FIND_PACKAGE_LibArchive=ON/-DDISABLE_ARCHIVE=ON/g; s/-DCMAKE_REQUIRE_FIND_PACKAGE_CURL=ON/-DDISABLE_CURL=ON/g; s/find_dependency\(CURL\)\n//g; s/find_dependency\(LibArchive\)\n//g' "$port_dir/portfile.cmake"
jq --arg commit "$commit" '."default-registry".baseline = $commit' \
    "$root_dir/vcpkg-configuration.json" > "$root_dir/vcpkg-configuration.json.tmp"
mv "$root_dir/vcpkg-configuration.json.tmp" "$root_dir/vcpkg-configuration.json"

cat > "$port_dir/README.md" <<EOF
Derived from the vcpkg Tesseract port at commit
\`$commit\` ($(date -u +%Y-%m-%d)).

This overlay differs only by removing the \`curl\` and \`libarchive\` dependencies
and disabling their CMake integrations. Refreshes must copy the upstream port
again and repeat only those changes.
EOF