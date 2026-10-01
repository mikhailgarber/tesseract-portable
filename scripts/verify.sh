#!/usr/bin/env bash
set -euo pipefail

: "${TEST_IMAGE:?TEST_IMAGE is required}"
: "${TESTDATA:?TESTDATA is required}"

binary="${1:?usage: verify.sh BINARY ARCHIVE}"
archive="${2:?usage: verify.sh BINARY ARCHIVE}"
readonly expected_text="${EXPECTED_TEXT:-Portable OCR verification}"

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

check_dependencies() {
    case "$(uname -s)" in
        Linux)
            while IFS= read -r dependency; do
                case "$dependency" in
                    libc.so.6|libm.so.6|libpthread.so.0|libdl.so.2|ld-linux*.so.*) ;;
                    *) printf 'unexpected Linux dependency: %s\n' "$dependency" >&2; return 1 ;;
                esac
            done < <(readelf -d "$binary" | sed -n 's/.*Shared library: \[\([^]]*\)\].*/\1/p')

            max_glibc="$(objdump -T "$binary" | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -Vu | tail -n 1 || true)"
            if [[ -n "$max_glibc" ]] && [[ "$(printf '%s\n%s\n' 'GLIBC_2.28' "$max_glibc" | sort -V | tail -n 1)" != 'GLIBC_2.28' ]]; then
                printf 'binary requires %s; maximum supported version is GLIBC_2.28\n' "$max_glibc" >&2
                return 1
            fi
            ;;
        Darwin)
            codesign --verify "$binary"
            while IFS= read -r dependency; do
                case "$dependency" in
                    /usr/lib/libSystem.B.dylib|/usr/lib/libc++.1.dylib) ;;
                    *) printf 'unexpected macOS dependency: %s\n' "$dependency" >&2; return 1 ;;
                esac
            done < <(otool -L "$binary" | awk 'NR > 1 { print $1 }')
            ;;
        MINGW*|MSYS*)
            while IFS= read -r dependency; do
                case "${dependency^^}" in
                    ADVAPI32.DLL|BCRYPT.DLL|COMCTL32.DLL|COMDLG32.DLL|GDI32.DLL|IPHLPAPI.DLL|KERNEL32.DLL|OLE32.DLL|OLEAUT32.DLL|SHELL32.DLL|SHLWAPI.DLL|USER32.DLL|USERENV.DLL|VERSION.DLL|WINMM.DLL|WS2_32.DLL) ;;
                    *) printf 'unexpected Windows dependency: %s\n' "$dependency" >&2; return 1 ;;
                esac
            done < <(dumpbin /dependents "$binary" | sed -nE 's/^[[:space:]]+([A-Za-z0-9_.-]+\.dll)[[:space:]]*$/\1/p')
            ;;
        *) printf 'unsupported operating system: %s\n' "$(uname -s)" >&2; return 1 ;;
    esac
}

check_archive() {
    local temporary_dir expected_checksum actual_checksum executable_name
    executable_name="$(basename "$binary")"
    expected_checksum="$(awk 'NR == 1 { print $1 }' "$archive.sha256")"
    actual_checksum="$(sha256 "$archive")"
    [[ "$actual_checksum" == "$expected_checksum" ]]

    tar -tzf "$archive" | grep -Fx "bin/$executable_name" >/dev/null
    tar -tzf "$archive" | grep -Fx BUILDINFO.json >/dev/null
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf "$temporary_dir"' RETURN
    tar -C "$temporary_dir" -xzf "$archive"
    jq -e '.tesseract and (.build | type == "number") and .target and .vcpkgCommit and (.packages | type == "object") and .builtAt' "$temporary_dir/BUILDINFO.json" >/dev/null
    while IFS= read -r package_name; do
        [[ -f "$temporary_dir/LICENSES/$package_name.txt" ]]
    done < <(jq -r '.packages | keys[]' "$temporary_dir/BUILDINFO.json")
    rm -rf "$temporary_dir"
    trap - RETURN
}

check_dependencies
"$binary" --version
if ! ocr_output="$("$binary" "$TEST_IMAGE" stdout --tessdata-dir "$(dirname "$TESTDATA")" -l eng 2>&1)"; then
    printf 'OCR command failed:\n%s\n' "$ocr_output" >&2
    exit 1
fi
if ! grep -F "$expected_text" <<<"$ocr_output" >/dev/null; then
    printf 'OCR output did not contain %q:\n%s\n' "$expected_text" "$ocr_output" >&2
    exit 1
fi
check_archive