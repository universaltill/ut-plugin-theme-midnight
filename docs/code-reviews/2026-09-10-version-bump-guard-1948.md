# Code review: manifest.json version-bump CI guard (ut-docs#1948)

**Date:** 2026-09-10
**Author:** Farshid Mirza (pipeline, Sonnet dev, `complexity:medium`)
**Independent reviewer:** Opus, fresh-context subagent (`isolation: "worktree"`)
**PR:** universaltill/ut-plugin-theme-midnight#4 (branch: `fix/1948-version-bump-guard-theme-midnight`)

## What shipped

`scripts/check-version-bump.sh` + `scripts/check-version-bump.test.sh` + a
new `version-bump` CI job in `.github/workflows/ci.yml` (PR-only) + a
`CLAUDE.md` note — a faithful port of `ut-plugin-language-de`'s guard
(ut-docs#1940, reviewed and merged) to this asset-only theme plugin.
Requires `manifest.json`'s `version` to change on any PR that touches a
shipped file (`manifest.json`, `assets/*`, `README.md`, `LICENSE` — the
same set `scripts/package.sh` bundles into the release artifact). Without
a bump, `auto-tag-release.yml` sees the version already tagged/released
and correctly no-ops — the change lands on `main` and silently never
ships. This repo hasn't hit the failure yet (the language packs have,
repeatedly); this is a preventive rollout, not a reactive one.

Scope: this PR covers `ut-plugin-theme-midnight` only, as the closest
remaining match to the already-proven asset-only shape. The rest of the
`ut-plugin-*` rollout (2 more theme repos, then a design variant needed
for the Go/WASM plugins whose `package.sh` bundles a gitignored `bin/`,
then `ut-plugin-integration-ai`'s non-array `package.sh` convention)
stays open on ut-docs#1948.

## Independent review findings

Verdict: **SAFE TO MERGE**, no blockers. Full verification run for real —
not just a diff read: 11/11 self-test cases reproduced locally by the
reviewer, `validate.sh`/`package.sh` both clean, the `version-bump` CI job
YAML parsed and confirmed structurally identical to `-de`'s, and five
independent scratch-commit simulations against the reviewer's own clone
(asset edit without bump → FAIL naming the file; bump too → PASS; bump to
an already-tagged version → FAIL; PR's own diff → no bump required;
package.sh mutated to add an untracked entry → entries-mirror self-test
correctly caught the drift). The reviewer also specifically chased down
whether `assets/*`'s bash glob crosses `/` into a new subdirectory (it
does — verified with a real `assets/icons/foo.svg` commit, guard correctly
required a bump) — this was the one edge case genuinely worth an empirical
check rather than an assumption, and it came back clean.

Four non-blocking findings, three inherited verbatim from the `-de`
reference (so also present in `-de` and `-es` today):

- **F1 (fixed in this PR):** the `# shellcheck disable=SC2053 -- ...`
  directive on `check-version-bump.sh` had trailing prose after the
  `key=value` pair, which shellcheck can't parse (SC1072/SC1073) — the
  same failure shape `universal-till/CLAUDE.md` (ut-docs#1943) already
  documents. Consequence: the directive was inert (SC2053 not actually
  suppressed) and shellcheck abandoned parsing the rest of the file from
  that point. Split into a plain comment + a bare `# shellcheck
  disable=SC2053` line. Verified: `shellcheck scripts/check-version-bump.sh`
  and `scripts/check-version-bump.test.sh` both exit 0 after the fix; the
  full self-test suite still passes 11/11.
- **F2 (accepted, not fixed here):** the guard checks the version merely
  *differs* between base and head, not that it *increases* — reproduced:
  editing `assets/theme.css` and setting `version` from `1.0.3` down to
  `0.9.9` passes with an "ok: ... bumped 1.0.3 -> 0.9.9" message, and
  `auto-tag-release.yml` would publish the downgrade. Low likelihood (a
  hand-typo), and the separate already-tagged check catches the common
  downgrade-to-a-released-version case. Real fix needs a semver tuple
  comparison; tracked as ecosystem-wide follow-up below rather than
  redesigned here mid-rollout.
- **F3 (accepted, not fixed here):** the test suite's entries-mirror
  pattern extraction (`grep -oE "'[^']*'" "$REAL_SCRIPT"`) scans every
  single-quoted literal in the whole script, not just the
  `SHIPPED_PATTERNS` array — no realistic false pass today (the only other
  quoted literals are `.` and format strings), but a future coincidental
  match would silently satisfy the check. Tightening the extraction to
  scope to the array is a same-shape fix across all three repos.
- **F4 (nit, not fixed here):** the `CLAUDE.md` note's docs/.github
  exemption line doesn't also name `scripts/` as exempt, though it
  demonstrably is (this PR itself touches only `scripts/`/`.github/`/
  `CLAUDE.md` and the guard correctly required no bump). Wording-only.

F2-F4 apply identically to `ut-plugin-language-de` and `-es` (verified by
direct inspection, not assumed) — filed as a follow-up note on ut-docs#1948
rather than reopening and re-reviewing two already-merged, already-shipped
guards mid-rollout for three low-severity nits.

## What was verified beyond automated tests

- Real CI run on PR #4: `version-bump`, `validate`, `authors` all green,
  including the guard's own 11/11 self-test lines in the job log.
- PR body's claims (self-test count, scratch-commit simulation, PR's own
  diff requiring no bump) independently reproduced by the reviewer against
  a fresh clone, not taken on the author's word.
- Secrets/PII scan across all changed files: clean (only
  `test@example.com`, RFC 2606 reserved, inside a test fixture's throwaway
  `git config`).
- Standards not applicable, stated explicitly rather than silently
  skipped: repository-pattern/SQL, `internal/money.Money`, i18n `{{ T }}`
  keys, RTL/logical-CSS, `web/help/` manual updates, compliance wording,
  kiosk-engine isolation, plugin signing, ent/depguard/data-residency — all
  out of scope for a CI-only shell-script change with no Go code, no UI
  surface, no locale strings, no money handling.
- No accepted ADR contradicted — this adds a CI gate, it changes no
  architectural decision.

## Safe-to-merge verdict

**Yes.** F1 fixed in this PR (shellcheck-clean, self-tests re-verified
11/11 after the fix). F2-F4 explicitly deferred as low-severity,
inherited-elsewhere nits — noted on ut-docs#1948 for a follow-up pass
across all three repos with the guard rather than piecemeal fixes.
