#!/usr/bin/env bash
set -euo pipefail

: "${TARGET:?TARGET is required}"
: "${VCPKG_ROOT:?VCPKG_ROOT is required}"
: "${VCPKG_EXE:?VCPKG_EXE is required}"
: "${TESSERACT_VERSION:?TESSERACT_VERSION is required}"
: "${BUILD_NUMBER:?BUILD_NUMBER is required}"

readonly package_names=(
    tesseract leptonica giflib libjpeg-turbo libpng libspng libwebp openjpeg tiff liblzma zlib
)
readonly output_dir="${OUTPUT_DIR:-$PWD/dist}"
readonly version="${TESSERACT_VERSION}+${BUILD_NUMBER}"
readonly installed_dir="${VCPKG_INSTALLED_DIR:-$PWD/vcpkg_installed}/$TARGET"
readonly stage_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$stage_dir"
}
trap cleanup EXIT

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

case "$(uname -s)" in
    MINGW*|MSYS*) executable="tesseract.exe" ;;
    *) executable="tesseract" ;;
esac

binary="$installed_dir/tools/tesseract/$executable"
if [[ ! -f "$binary" ]]; then
    printf 'Tesseract binary not found at %s\n' "$binary" >&2
    exit 1
fi

mkdir -p "$stage_dir/bin" "$stage_dir/LICENSES" "$output_dir"
cp "$binary" "$stage_dir/bin/$executable"
chmod +x "$stage_dir/bin/$executable"

packages_json='{}'
for package_name in "${package_names[@]}"; do
    copyright="$installed_dir/share/$package_name/copyright"
    if [[ ! -f "$copyright" ]]; then
        printf 'license for %s not found at %s\n' "$package_name" "$copyright" >&2
        exit 1
    fi
    cp "$copyright" "$stage_dir/LICENSES/$package_name.txt"

    package_version="$("$VCPKG_EXE" list --triplet "$TARGET" | awk -v package_name="$package_name" -v target="$TARGET" '$1 == package_name ":" target { print $2 }')"
    if [[ -z "$package_version" ]]; then
        printf 'installed version for %s was not found\n' "$package_name" >&2
        exit 1
    fi
    packages_json="$(jq --arg name "$package_name" --arg version "$package_version" '. + {($name): $version}' <<<"$packages_json")"
done

jq -n \
    --arg tesseract "$TESSERACT_VERSION" \
    --argjson build "$BUILD_NUMBER" \
    --arg target "$TARGET" \
    --arg vcpkg_commit "${VCPKG_COMMIT:?VCPKG_COMMIT is required}" \
    --arg built_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson packages "$packages_json" \
    '{tesseract: $tesseract, build: $build, target: $target, vcpkgCommit: $vcpkg_commit, packages: $packages, builtAt: $built_at}' \
    > "$stage_dir/BUILDINFO.json"

archive="$output_dir/tesseract-${version}-${TARGET}.tar.gz"
tar -C "$stage_dir" -czf "$archive" bin LICENSES BUILDINFO.json
printf '%s  %s\n' "$(sha256 "$archive")" "$(basename "$archive")" > "$archive.sha256"