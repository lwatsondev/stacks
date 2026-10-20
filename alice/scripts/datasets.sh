#!/bin/sh

# Written by Claude, tested extensively by a human.

set -eu

usage() {
    echo "Usage: $0 prune|merge [-n|--dry-run]" >&2
    echo "  prune  Delete events from staging that default already has" >&2
    echo "  merge  Move staging into default, skipping those events, then empty staging" >&2
    echo "  -n, --dry-run  Show what would change without changing anything" >&2
}

dry_run=false
case "${2:-}" in
    "") ;;
    -n | --dry-run) dry_run=true ;;
    *)
        usage
        exit 1
        ;;
esac

cd "$(dirname "$0")/../data/datasets"

for d in default staging; do
    [ -d "$d/images" ] || { echo "Dataset $d is missing, create it in alice: Viewer then Dataset in the left sidebar, then + Create New Dataset at the end of the dropdown at the far left of the top toolbar" >&2; exit 1; }
done

in_default() {
    for f in default/images/*/"$1.jpg"; do
        [ -e "$f" ] && return 0
    done
    return 1
}

prune() {
    removed=0
    for img in staging/images/*/*.jpg; do
        [ -e "$img" ] || continue
        n=$(basename "$img" .jpg)
        in_default "$n" || continue
        if $dry_run; then
            echo "Would delete $img"
        else
            rm -f "$img" staging/labels/*/"$n.txt"
        fi
        removed=$((removed + 1))
    done
    if $dry_run; then
        echo "Would prune $removed events already in default"
    else
        echo "Pruned $removed events already in default"
    fi
}

merge() {
    command -v jq > /dev/null || { echo "jq is not installed" >&2; exit 1; }
    moved=0
    skipped=0
    # Files a dry run would move, so it can count what emptying staging deletes.
    moving=0
    for s in train val; do
        for img in staging/images/"$s"/*.jpg; do
            [ -e "$img" ] || continue
            n=$(basename "$img" .jpg)
            if in_default "$n"; then
                skipped=$((skipped + 1))
                continue
            fi
            if $dry_run; then
                echo "Would move $img"
                moving=$((moving + 1))
                if [ -e staging/labels/"$s"/"$n.txt" ]; then
                    moving=$((moving + 1))
                fi
            else
                mv "$img" default/images/"$s"/
                if [ -e staging/labels/"$s"/"$n.txt" ]; then
                    mv staging/labels/"$s"/"$n.txt" default/labels/"$s"/
                fi
            fi
            moved=$((moved + 1))
        done
    done
    if $dry_run; then
        left=$(($(find staging -type f | wc -l) - moving))
        echo "Would merge $moved images into default, skip $skipped already there, and delete the other $left files in staging"
        return
    fi
    if [ -f staging/camera_map.json ]; then
        [ -f default/camera_map.json ] || echo '{}' > default/camera_map.json
        jq -s '.[0] * .[1]' default/camera_map.json staging/camera_map.json > camera_map.tmp
        mv camera_map.tmp default/camera_map.json
    fi
    # Keeps the directories, alice can only select a dataset that has images/.
    find staging -type f -delete
    echo "Merged $moved images into default, skipped $skipped already there, emptied staging"
}

case "${1:-}" in
    prune) prune ;;
    merge) merge ;;
    *)
        usage
        exit 1
        ;;
esac
