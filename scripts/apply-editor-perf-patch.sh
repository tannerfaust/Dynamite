#!/bin/bash
#
# apply-editor-perf-patch.sh
#
# Re-applies the editor resize-performance patches to the resolved Swift
# Package checkout(s). Run this if you ever "Reset Package Caches" in Xcode or
# delete DerivedData, which would restore the unpatched upstream sources.
#
# The patch fixes severe few-FPS stutter when resizing the window or dragging
# split-view dividers. See patches/README.md for the full explanation.
#
# Safe to run repeatedly: it skips any checkout that already has the fixes.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEXTVIEW_PATCH="$REPO_ROOT/patches/codeedittextview-resize-perf.patch"
SOURCEEDITOR_PATCH="$REPO_ROOT/patches/codeeditsourceeditor-resize-perf.patch"

for patch in "$TEXTVIEW_PATCH" "$SOURCEEDITOR_PATCH"; do
    if [[ ! -f "$patch" ]]; then
        echo "error: patch not found at $patch" >&2
        exit 1
    fi
done

collect_candidates() {
    local package_name="$1"
    local candidates=()

    [[ -d "$REPO_ROOT/.SourcePackages/checkouts/$package_name" ]] && \
        candidates+=("$REPO_ROOT/.SourcePackages/checkouts/$package_name")

    while IFS= read -r dir; do
        candidates+=("$dir")
    done < <(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 4 \
                -type d -path "*Dynamite-*/SourcePackages/checkouts/$package_name" 2>/dev/null)

    printf '%s\n' "${candidates[@]}"
}

is_textview_patched() {
    local checkout="$1"
    [[ -f "$checkout/Sources/CodeEditTextView/TextLine/FastID.swift" ]] &&
        grep -q "FastID.next" "$checkout/Sources/CodeEditTextView/TextLine/LineFragment.swift" 2>/dev/null &&
        grep -q "layoutManager.frozenWrapWidth != nil" \
            "$checkout/Sources/CodeEditTextView/TextView/TextView+Layout.swift" 2>/dev/null &&
        grep -q "scheduleFinalWrapRelayout" \
            "$checkout/Sources/CodeEditTextView/TextView/TextView+Layout.swift" 2>/dev/null
}

is_sourceeditor_patched() {
    local checkout="$1"
    grep -q "sizingOptions = \\[]" \
        "$checkout/Sources/CodeEditSourceEditor/Find/PanelView/FindPanelHostingView.swift" 2>/dev/null &&
        grep -q "findPanelHeightConstraint" \
            "$checkout/Sources/CodeEditSourceEditor/Find/FindViewController.swift" 2>/dev/null
}

apply_package_patch() {
    local package_name="$1"
    local expected_revision="$2"
    local patch="$3"
    local source_dir="$4"
    local candidates=()

    while IFS= read -r checkout; do
        [[ -n "$checkout" ]] && candidates+=("$checkout")
    done < <(collect_candidates "$package_name")

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "No $package_name checkout found. Build the project once, then re-run." >&2
        exit 1
    fi

    for checkout in "${candidates[@]}"; do
        revision="$(git -C "$checkout" rev-parse --short HEAD 2>/dev/null || true)"
        if [[ "$revision" != "$expected_revision" ]]; then
            echo "unsupported $package_name checkout at $checkout (HEAD $revision, expected $expected_revision)." >&2
            echo "Update the patch before building against this package revision." >&2
            exit 1
        fi

        if [[ "$package_name" == "CodeEditTextView" ]]; then
            if is_textview_patched "$checkout"; then
                echo "already patched: $checkout"
                continue
            fi
        elif is_sourceeditor_patched "$checkout"; then
            echo "already patched: $checkout"
            continue
        fi

        echo "patching: $checkout"
        chmod -R u+w "$checkout/$source_dir" 2>/dev/null || true
        if git -C "$checkout" apply "$patch" 2>/dev/null; then
            echo "  applied"
        else
            if [[ "$checkout" != "$REPO_ROOT/.SourcePackages/"* ]]; then
                echo "warning: skipped stale DerivedData checkout with partial local edits: $checkout" >&2
                echo "         Reset that package cache or delete that DerivedData folder before using it directly from Xcode." >&2
                continue
            fi
            echo "failed to apply $package_name patch (version mismatch or partial local edits)." >&2
            exit 1
        fi
    done
}

apply_package_patch "CodeEditTextView" "d7ac3f1" "$TEXTVIEW_PATCH" "Sources/CodeEditTextView"
apply_package_patch "CodeEditSourceEditor" "ee0c00a" "$SOURCEEDITOR_PATCH" "Sources/CodeEditSourceEditor"

echo "Done."
