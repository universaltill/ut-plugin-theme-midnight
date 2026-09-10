# Theme plugin repo — rules

One Universal Till POS **theme plugin** per repo. Full standards: `docs` repo →
`reference/coding-standards.md`.

- Asset-only plugin: `runtime: "none"`, no executable, `device_arch: "any"`,
  exactly one `type: "theme"` entry whose `config.css` points at a stylesheet
  in this repo.
- Layout changes go through the POS `pos-container` grid areas
  (`basket|products|journal|tender`); style via CSS only.
- The marketplace requires `permissions` (≥1) and `locales` (≥1); keep them.
- Release flow: bump `manifest.json` version → tag `v<version>` → push tag →
  the Release workflow validates, packages, publishes to the marketplace and
  (dev only, `AUTO_APPROVE` repo var) auto-approves+signs.
- `scripts/validate.sh` must pass before packaging; artifacts carry no `./`
  tar members (the POS importer rejects them).
- **Any PR that touches a shipped file — `manifest.json`, `assets/*`,
  `README.md`, `LICENSE` — must bump `manifest.json`'s `version` in the same
  PR.** `scripts/package.sh` bundles exactly those files into the release
  artifact, and `auto-tag-release.yml` only cuts a release when the version
  differs from the last tag; without a bump the change lands on `main` and
  then silently never ships (ut-docs#1940). Enforced by
  `scripts/check-version-bump.sh` (CI job `version-bump`, PRs only). A PR
  touching only `docs/`/`.github/` is exempt.
