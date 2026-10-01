#!/usr/bin/env bash
set -euo pipefail

: "${TARGET:?TARGET is required}"
: "${VCPKG_COMMIT:?VCPKG_COMMIT is required}"

readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly vcpkg_root="${VCPKG_ROOT:-$root_dir/.vcpkg}"
if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is required to read the Tesseract port version\n' >&2
    exit 1
fi
readonly tesseract_version="$(jq -er '.version' "$root_dir/overlay-ports/tesseract/vcpkg.json")"
readonly build_number="${BUILD_NUMBER:-1}"
readonly output_dir="${OUTPUT_DIR:-$root_dir/dist}"
readonly testdata="${TESTDATA:-$root_dir/.test-data/eng.traineddata}"

if [[ ! -d "$vcpkg_root/.git" ]]; then
    git init "$vcpkg_root"
    git -C "$vcpkg_root" remote add origin https://github.com/microsoft/vcpkg.git
fi
git -C "$vcpkg_root" fetch --depth 1 origin "$VCPKG_COMMIT"
git -C "$vcpkg_root" checkout --force FETCH_HEAD

case "$(uname -s)" in
    MINGW*|MSYS*)
        cmd.exe //c "$(cygpath -w "$vcpkg_root")\\bootstrap-vcpkg.bat" -disableMetrics
        vcpkg_exe="$vcpkg_root/vcpkg.exe"
        executable="tesseract.exe"
        ;;
    *)
        "$vcpkg_root/bootstrap-vcpkg.sh" -disableMetrics
        vcpkg_exe="$vcpkg_root/vcpkg"
        executable="tesseract"
        ;;
esac

if [[ "${GITHUB_ACTIONS:-}" == 'true' ]]; then
    export VCPKG_BINARY_SOURCES="${VCPKG_BINARY_SOURCES:-clear;x-gha,readwrite}"
else
    export VCPKG_BINARY_SOURCES="${VCPKG_BINARY_SOURCES:-clear;files,$HOME/.cache/vcpkg,readwrite}"
fi
"$vcpkg_exe" install --triplet "$TARGET" --x-manifest-root "$root_dir"

binary="$root_dir/vcpkg_installed/$TARGET/tools/tesseract/$executable"
if [[ "$(uname -s)" == Darwin ]]; then
    strip "$binary"
    codesign --force -s - "$binary"
fi

"$root_dir/scripts/fetch-testdata.sh" "$testdata"
export VCPKG_ROOT="$vcpkg_root"
export VCPKG_INSTALLED_DIR="$root_dir/vcpkg_installed"
export VCPKG_EXE="$vcpkg_exe"
export TESSERACT_VERSION="$tesseract_version"
export BUILD_NUMBER="$build_number"
export OUTPUT_DIR="$output_dir"
"$root_dir/scripts/package.sh"

archive="$output_dir/tesseract-${tesseract_version}+${build_number}-${TARGET}.tar.gz"
TEST_IMAGE="$root_dir/test/hello.png" \
TESTDATA="$testdata" \
"$root_dir/scripts/verify.sh" "$binary" "$archive"