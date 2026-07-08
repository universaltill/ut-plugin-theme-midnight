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
