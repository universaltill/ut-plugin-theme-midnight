# Code review: auto-tag-release.yml (rollout batch)

**Date:** 2026-09-08
**Card:** ut-docs#1700 (rollout of ut-docs#1694's workflow to the remaining `ut-plugin-*` repos)
**Author:** scrum-master pipeline (cloud cycle, `lane:cloud-41`), on behalf of Pouria Teimouri

## What changed

Added `.github/workflows/auto-tag-release.yml` — a verbatim copy of the
canonical, independently-reviewed workflow already merged into
`ut-plugin-tax-de` (see that repo's
`docs/code-reviews/2026-09-07-auto-tag-release-workflow-1694.md` for the
original design review, including the recursion-guard analysis and the
behavioral test suite run against a throwaway git repo). No other file
changed.

## Verification performed (independent review, fresh-context Sonnet)

- Diffed against the canonical `ut-plugin-tax-de` copy: **byte-identical**.
- Confirmed this repo's `release.yml` triggers on `push: tags: ["v*"]` and
  declares `workflow_dispatch` inputs `channel` (choice, includes `stable`)
  and `publish` (boolean) — exactly what the new workflow's dispatch step
  assumes. No per-repo adaptation needed.
- Confirmed `manifest.json` is at repo root, matching the script's
  assumption.
- Checked live drift: `manifest.json` version `1.0.3`, newest tag already
  `v1.0.3` on origin — **no drift**. Merging is expected to be a no-op (the
  idempotency guard finds the tag already present and exits `created=false`)
  on the next push to main, not an immediate tag/release.
- Confirmed `contents: write` + `actions: write` permissions are minimal
  and match exactly what the two steps do; no other workflow in this repo
  (`ci.yml`, `commit-attribution.yml`) overlaps with a push-to-main tagging
  trigger.

Verdict: **SAFE TO MERGE**, no blocking findings, no deviation from the
canonical copy.

## Non-goals confirmed out of scope

- Changing `release.yml`/`ci.yml`.
- Adding a `concurrency:` group (accepted-not-fixed on the original
  ut-docs#1694 review; unchanged here).
