#!/usr/bin/env bash
set -euo pipefail

# Moves every digest-pinned image in build.yml (<image>[:<tag>]@sha256:<digest>) to the digest
# its tag (default latest) points to now.

readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly workflow="$root_dir/.github/workflows/build.yml"
readonly accept='application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'

current_digest() {
    local image="$1" tag="$2" registry repository auth=()
    if [[ "$image" == */* && "${image%%/*}" == *.* ]]; then
        registry="${image%%/*}"
        repository="${image#*/}"
    else
        registry='registry-1.docker.io'
        repository="$image"
        [[ "$repository" == */* ]] || repository="library/$repository"
        local token
        token="$(curl --fail --silent --show-error \
            "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$repository:pull" | jq -er '.token')"
        auth=(--header "Authorization: Bearer $token")
    fi
    curl --fail --silent --show-error --head "${auth[@]}" --header "Accept: $accept" \
        "https://$registry/v2/$repository/manifests/$tag" |
        tr -d '\r' | awk 'tolower($1) == "docker-content-digest:" { print $2 }'
}

grep -oE '[a-z0-9./_-]+(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}' "$workflow" | sort -u |
while IFS= read -r reference; do
    name="${reference%@*}"
    old_digest="${reference#*@}"
    image="${name%:*}"
    tag=latest
    [[ "$name" == *:* ]] && tag="${name##*:}"
    new_digest="$(current_digest "$image" "$tag")"
    if [[ ! "$new_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
        printf 'no digest for %s:%s\n' "$image" "$tag" >&2
        exit 1
    fi
    if [[ "$new_digest" != "$old_digest" ]]; then
        printf '%s: %s -> %s\n' "$name" "$old_digest" "$new_digest"
        sed -i.bak "s|$name@$old_digest|$name@$new_digest|g" "$workflow"
        rm -f "$workflow.bak"
    fi
done
