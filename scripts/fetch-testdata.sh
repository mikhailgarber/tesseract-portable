#!/usr/bin/env bash
set -euo pipefail

readonly model_tag="tessdata-4.1.0"
readonly model_name="eng.traineddata"
readonly model_sha256="daa0c97d651c19fba3b25e81317cd697e9908c8208090c94c3905381c23fc047"
readonly upstream_url="https://raw.githubusercontent.com/tesseract-ocr/tessdata/4.1.0/${model_name}"

destination="${1:?usage: fetch-testdata.sh DESTINATION}"
mkdir -p "$(dirname "$destination")"

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

downloaded=false
if [[ -n "${GITHUB_REPOSITORY:-}" ]] && command -v gh >/dev/null 2>&1; then
    if GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" gh release download "$model_tag" \
        --repo "$GITHUB_REPOSITORY" --pattern "$model_name" --output "$destination" --clobber; then
        downloaded=true
    fi
fi

if [[ "$downloaded" == false ]]; then
    curl --fail --location --retry 3 --output "$destination" "$upstream_url"
fi

actual_sha256="$(sha256 "$destination")"
if [[ "$actual_sha256" != "$model_sha256" ]]; then
    printf 'unexpected checksum for %s: got %s, expected %s\n' \
        "$model_name" "$actual_sha256" "$model_sha256" >&2
    exit 1
fi