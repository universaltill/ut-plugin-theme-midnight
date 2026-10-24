#!/usr/bin/env bash
#
# Requires a manifest.json version bump on any PR that touches a shipped
# file (ut-docs#1940, rolled out here per ut-docs#1948).
#
# WHY THIS EXISTS: scripts/package.sh bundles manifest.json, assets/ and
# README.md (plus LICENSE when present) into the marketplace release
# artifact. None of this repo's other checks (validate, authors) look at
# the version field, so a PR that edits assets/theme.css but forgets to
# bump manifest.json's version lands on main, passes every check, and then
# SILENTLY NEVER SHIPS: auto-tag-release.yml reads the unchanged version,
# sees v<version> already tagged/released, and correctly does nothing.
# main and the marketplace diverge with no failing signal anywhere. This
# exact failure has already needed hand repair multiple times in the
# language-pack plugins (v1.1.32, v1.1.33->34, and twice more on
# 2026-09-09 alone) — this repo hasn't hit it yet, but the mechanism that
# causes it (package.sh's bundle vs. no CI check on version) is identical
# here, hence the preventive rollout.
#
# WHAT COUNTS AS "SHIPPED": deliberately keyed off the same set
# scripts/package.sh actually bundles, not "any file" -- a docs/code-reviews/
# record or a workflow-only edit must never force a version bump. Keep this
# list mirrored to package.sh's own `entries=(...)` line; nothing enforces
# that automatically, so a change to package.sh's bundle needs a matching
# edit here (and check-version-bump.test.sh's "entries mirror" case exists
# to catch drift between the two by re-reading package.sh's own source).
# The check logic itself lives in scripts/check-version-bump.body.sh, sourced
# at the bottom: one canonical body, byte-identical in every ut-plugin-* repo
# (canonical copy: ut-docs scripts/templates/check-version-bump.body.sh,
# ut-docs#4489). Never edit the body here; only SHIPPED_PATTERNS (and
# SHIPPED_NOTE) are per-repo.
set -euo pipefail
cd "$(dirname "$0")/.."

# SHIPPED_PATTERNS is read by the sourced body, which shellcheck does not
# follow without -x.
# shellcheck disable=SC2034
SHIPPED_PATTERNS=(
    'manifest.json'
    'assets/*'
    'README.md'
    'LICENSE'
)

# shellcheck source=scripts/check-version-bump.body.sh
. scripts/check-version-bump.body.sh
