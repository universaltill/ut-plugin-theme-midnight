#!/usr/bin/env bash
# Tests for scripts/check-version-bump.sh (ut-docs#1940, ut-docs#1948).
#
# Each case builds a throwaway git repo (real commits, so BASE_SHA/HEAD_SHA
# and `git diff`/`git show` all behave exactly as they do against a real
# PR) with just enough of this repo's layout for the script under test to
# operate on, then runs the real script against a BASE_SHA..HEAD_SHA pair
# and asserts both the exit code and that the failure output actually names
# the changed shipped file(s) and the version -- a script that exits
# non-zero for the wrong reason must not be mistaken for a passing test of
# the real check.
set -euo pipefail
cd "$(dirname "$0")/.."

REAL_SCRIPT="$(pwd)/scripts/check-version-bump.sh"
PACKAGE_SH="$(pwd)/scripts/package.sh"
FAILS=0

work_dir=""
cleanup() {
    # `|| true`: under `set -e`, a trap function's own exit status can
    # become the script's final exit status -- without this, a clean run
    # that happens to fire EXIT while work_dir is still "" (nothing to
    # clean up yet) would report failure via `[ -n "" ]`'s exit 1, even
    # though every case passed.
    [ -n "$work_dir" ] && rm -rf "$work_dir"
    true
}
trap cleanup EXIT

# fresh_repo
# Builds a throwaway git repo ($case_dir) with an initial commit carrying a
# minimal but complete layout (manifest.json v1.0.0, assets/theme.css,
# README.md, LICENSE, a workflow file, a docs file). Sets $base_sha to that
# commit. The script under test is copied in (not symlinked -- it does
# `cd "$(dirname "$0")/.."`, which resolves relative to ITS OWN path, so it
# must run from inside the fixture).
fresh_repo() {
    [ -n "$work_dir" ] && rm -rf "$work_dir"
    work_dir="$(mktemp -d)"
    case_dir="${work_dir}/repo"
    mkdir -p "${case_dir}/scripts" "${case_dir}/assets" "${case_dir}/.github/workflows" "${case_dir}/docs/code-reviews"
    cp "$REAL_SCRIPT" "${case_dir}/scripts/check-version-bump.sh"
    chmod +x "${case_dir}/scripts/check-version-bump.sh"

    cat >"${case_dir}/manifest.json" <<'JSON'
{
  "id": "com.universaltill.theme-midnight",
  "name": "Midnight Theme",
  "version": "1.0.0",
  "runtime": "none",
  "device_arch": "any",
  "permissions": ["ui.theme"],
  "locales": ["en-US"],
  "entries": [
    {
      "type": "theme",
      "key": "midnight",
      "config": {"css": "assets/theme.css"}
    }
  ]
}
JSON
    echo "body { background: #000; }" >"${case_dir}/assets/theme.css"
    echo "# Midnight theme" >"${case_dir}/README.md"
    echo "MIT" >"${case_dir}/LICENSE"
    echo "name: CI" >"${case_dir}/.github/workflows/ci.yml"

    (
        cd "$case_dir"
        git init -q
        git config user.email test@example.com
        git config user.name Test
        git add -A
        git commit -q -m "initial"
    )
    base_sha=$(cd "$case_dir" && git rev-parse HEAD)
}

# commit_change - stages whatever the caller already edited in $case_dir
# and commits it, setting $head_sha.
commit_change() {
    (cd "$case_dir" && git add -A && git commit -q -m "change")
    head_sha=$(cd "$case_dir" && git rev-parse HEAD)
}

run_check() {
    (cd "$case_dir" && BASE_SHA="$base_sha" HEAD_SHA="$head_sha" bash scripts/check-version-bump.sh)
}

assert_pass() {
    local name="$1"
    local out rc
    set +e
    out="$(run_check 2>&1)"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
        echo "FAIL [$name]: expected exit 0, got $rc. Output:"
        echo "$out"
        FAILS=$((FAILS + 1))
        return
    fi
    echo "ok   [$name]"
}

assert_fail_containing() {
    local name="$1"
    shift
    local out rc
    set +e
    out="$(run_check 2>&1)"
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        echo "FAIL [$name]: expected non-zero exit, got 0. Output:"
        echo "$out"
        FAILS=$((FAILS + 1))
        return
    fi
    local needle
    for needle in "$@"; do
        if ! grep -qF -- "$needle" <<<"$out"; then
            echo "FAIL [$name]: exited non-zero (good) but output did not mention expected reason ('$needle'). Output:"
            echo "$out"
            FAILS=$((FAILS + 1))
            return
        fi
    done
    echo "ok   [$name] (exit $rc, mentions: $*)"
}

# --- case 1: asset changed, version NOT bumped -> FAIL, names the file ----
fresh_repo
echo "body { background: #001; }" >"${case_dir}/assets/theme.css"
commit_change
assert_fail_containing "asset changed, no bump" \
    "assets/theme.css" "manifest.json" "1.0.0" "FAIL"

# --- case 2: asset changed, version bumped -> PASS -------------------------
fresh_repo
echo "body { background: #001; }" >"${case_dir}/assets/theme.css"
python3 -c "
import json
m = json.load(open('${case_dir}/manifest.json'))
m['version'] = '1.0.1'
json.dump(m, open('${case_dir}/manifest.json', 'w'))
"
commit_change
assert_pass "asset changed, version bumped"

# --- case 3: README changed, version NOT bumped -> FAIL --------------------
fresh_repo
echo "# Midnight theme, updated" >"${case_dir}/README.md"
commit_change
assert_fail_containing "README changed, no bump" "README.md" "FAIL"

# --- case 4: only manifest.json touched (version bump itself) -> PASS -----
# The bump is itself a shipped-file change, and the version differs -- must
# not require a SECOND shipped file to also have changed.
fresh_repo
python3 -c "
import json
m = json.load(open('${case_dir}/manifest.json'))
m['version'] = '1.0.1'
json.dump(m, open('${case_dir}/manifest.json', 'w'))
"
commit_change
assert_pass "manifest-only version bump"

# --- case 5: docs-only change -> PASS, no bump required --------------------
fresh_repo
echo "# review" >"${case_dir}/docs/code-reviews/2026-09-10-example.md"
commit_change
assert_pass "docs-only change, no bump required"

# --- case 6: workflow-only change -> PASS, no bump required ----------------
fresh_repo
echo "name: CI (updated)" >"${case_dir}/.github/workflows/ci.yml"
commit_change
assert_pass "workflow-only change, no bump required"

# --- case 7: manifest.json changed but NOT the version (e.g. permissions)
# still counts as a shipped-file change, still requires the version to move.
fresh_repo
python3 -c "
import json
m = json.load(open('${case_dir}/manifest.json'))
m['permissions'] = ['ui.theme', 'storage']
json.dump(m, open('${case_dir}/manifest.json', 'w'))
"
commit_change
assert_fail_containing "manifest changed without version bump" "manifest.json" "FAIL"

# --- case 8: SHIPPED_PATTERNS mirrors package.sh's own bundle entries -----
# package.sh's `entries=(...)` line is the actual source of truth for what
# ships; this parses the ACTUAL array contents out of that line (not a
# hardcoded restatement of what we expect it to say) and asserts every name
# it lists is also covered by SHIPPED_PATTERNS in the real script, so a real
# change to package.sh's bundle (e.g. adding a CHANGELOG.md entry) is
# caught here instead of silently drifting undetected.
entries_line=$(grep -m1 '^entries=' "$PACKAGE_SH") || entries_line=""
if [ -z "$entries_line" ]; then
    echo "FAIL [entries mirror]: could not find package.sh's entries=(...) line"
    FAILS=$((FAILS + 1))
else
    array_body="${entries_line#entries=(}"
    array_body="${array_body%)}"
    read -r -a bundle_entries <<<"$array_body"
    patterns=$(grep -oE "'[^']*'" "$REAL_SCRIPT" | tr -d "'")
    mismatch=0
    for entry in "${bundle_entries[@]}"; do
        if ! grep -qxF "$entry" <<<"$patterns" && ! grep -qxF "${entry}/*" <<<"$patterns"; then
            echo "FAIL [entries mirror]: package.sh bundles '$entry' but SHIPPED_PATTERNS in check-version-bump.sh has no matching entry"
            mismatch=1
        fi
    done
    # LICENSE ships conditionally ([ -f LICENSE ] && entries+=(LICENSE)),
    # so it never appears on package.sh's own entries=(...) line -- checked
    # separately here rather than assumed.
    if ! grep -qxF "LICENSE" <<<"$patterns"; then
        echo "FAIL [entries mirror]: package.sh conditionally bundles LICENSE (when present) but SHIPPED_PATTERNS has no LICENSE entry"
        mismatch=1
    fi
    if [ "$mismatch" -eq 0 ]; then
        echo "ok   [entries mirror] (package.sh: ${bundle_entries[*]} + conditional LICENSE)"
    else
        FAILS=$((FAILS + 1))
    fi
fi

# --- case 9: base branch ALSO moved forward independently, with its own --
# shipped change + bump (multi-lane / ut-docs#1940-review B1 regression).
# A two-dot diff against a moving base.sha would let that OTHER PR's
# landed bump silently cover for THIS PR's own missing one. This PR's own
# change (relative to the true merge-base) does NOT bump -- must still
# FAIL even though base_sha's tip now carries a higher version than this
# PR's own unbumped head.
fresh_repo
mergebase_sha="$base_sha"
# "main" advances independently with its own shipped change + bump.
echo "body { background: #002; }" >"${case_dir}/assets/theme.css"
python3 -c "
import json
m = json.load(open('${case_dir}/manifest.json'))
m['version'] = '1.0.1'
json.dump(m, open('${case_dir}/manifest.json', 'w'))
"
(cd "$case_dir" && git add -A && git commit -q -m "main advances, bumped")
main_tip_sha=$(cd "$case_dir" && git rev-parse HEAD)
# This PR's own head branches from the ORIGINAL base, not main's advanced
# tip, and changes a shipped file without bumping.
(cd "$case_dir" && git checkout -q "$mergebase_sha")
echo "body { background: #003; }" >"${case_dir}/assets/theme.css"
(cd "$case_dir" && git add -A && git commit -q -m "PR change, no bump")
pr_head_sha=$(cd "$case_dir" && git rev-parse HEAD)
base_sha="$main_tip_sha"
head_sha="$pr_head_sha"
assert_fail_containing "base moved forward independently, PR itself didn't bump" \
    "assets/theme.css" "FAIL"

# --- case 10: pre-release version suffix must not crash past the FAIL ----
# path (ut-docs#1940-review B2 regression). validate.sh's version regex
# (^\d+\.\d+\.\d+, unanchored at the end) and auto-tag-release.yml's own
# pattern both already accept "-prerelease" suffixes, so this is a real
# reachable state, not a hypothetical.
fresh_repo
python3 -c "
import json
m = json.load(open('${case_dir}/manifest.json'))
m['version'] = '1.0.0-beta.1'
json.dump(m, open('${case_dir}/manifest.json', 'w'))
"
(cd "$case_dir" && git add -A && git commit -q -m "adopt pre-release version scheme")
base_sha=$(cd "$case_dir" && git rev-parse HEAD)
echo "body { background: #004; }" >"${case_dir}/assets/theme.css"
commit_change
assert_fail_containing "pre-release version suffix, no bump" "FAIL"

# --- case 11: version differs but is ALREADY TAGGED elsewhere ------------
# (ut-docs#1940-review N1). auto-tag-release.yml no-ops on an existing tag,
# so reusing one is the same silent-never-ships failure with a green guard.
fresh_repo
(cd "$case_dir" && git tag "v1.0.1")
echo "body { background: #005; }" >"${case_dir}/assets/theme.css"
python3 -c "
import json
m = json.load(open('${case_dir}/manifest.json'))
m['version'] = '1.0.1'
json.dump(m, open('${case_dir}/manifest.json', 'w'))
"
commit_change
assert_fail_containing "bumped to an already-tagged version" "FAIL" "v1.0.1" "ALREADY TAGGED"

if [ "$FAILS" -ne 0 ]; then
    echo ""
    echo "$FAILS case(s) failed."
    exit 1
fi
echo ""
echo "All check-version-bump.sh cases passed."
