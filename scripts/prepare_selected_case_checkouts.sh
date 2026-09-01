#!/usr/bin/env bash
set -euo pipefail

BASE="/home/java8-flakesync/scripts"
SOURCE_ROOT="$BASE/projects"
DELTA_ROOT="$BASE/projects-For-Delta"

prepare_checkout() {
    local slug="$1"
    local sha="$2"
    local source="$SOURCE_ROOT/$slug"
    local target="$DELTA_ROOT/$slug"

    if [[ -d "$target/.git" ]]; then
        if git -C "$target" cat-file -e "$sha^{commit}" 2>/dev/null; then
            echo "READY delta checkout: $slug"
            return
        fi
        echo "Existing delta checkout does not contain $sha: $target" >&2
        return 1
    fi

    if [[ ! -d "$source/.git" ]]; then
        echo "Missing cached source checkout: $source" >&2
        return 1
    fi
    if ! git -C "$source" cat-file -e "$sha^{commit}" 2>/dev/null; then
        echo "Cached source does not contain required commit $sha: $source" >&2
        return 1
    fi

    mkdir -p "$(dirname "$target")"
    git clone --local --no-hardlinks "$source" "$target"
    git -C "$target" checkout --detach "$sha"
    echo "CREATED delta checkout from local cache: $slug"
}

prepare_checkout "flaxsearch/luwak" "c27ec08c803db6ca6be1b6e8017f45667e603161"
prepare_checkout "javadelight/delight-nashorn-sandbox" "da35edc0a75424bad8cbf60959fae253202154c4"
prepare_checkout "davidmoten/rxjava2-extras" "7663d3b19295f12c35f80594efa1e507e98650b1"
