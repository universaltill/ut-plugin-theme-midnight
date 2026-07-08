#!/usr/bin/env bash
# Validates the theme manifest: marketplace-required fields
# (id/name/semver/permissions/locales), asset-only runtime, exactly one
# type="theme" entry, and that its config.css file exists.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, os, re, sys
m = json.load(open("manifest.json"))
errs = []
if not re.match(r'^[a-z0-9]+([.-][a-z0-9]+)*$', m.get("id","")): errs.append("bad id")
if not m.get("name"): errs.append("missing name")
if not re.match(r'^\d+\.\d+\.\d+', m.get("version","")): errs.append("bad version")
if not m.get("permissions"): errs.append("missing permissions")
if not m.get("locales"): errs.append("missing locales")
if m.get("runtime") != "none": errs.append("runtime must be 'none' (asset-only)")
if m.get("device_arch") != "any": errs.append("device_arch must be 'any'")
themes = [e for e in m.get("entries", []) if e.get("type") == "theme"]
if len(themes) != 1:
    errs.append(f"expected exactly 1 theme entry, got {len(themes)}")
else:
    css = themes[0].get("config", {}).get("css", "")
    if not css: errs.append("theme entry missing config.css")
    elif not os.path.isfile(css): errs.append(f"css not found: {css}")
if errs:
    print("FAIL: " + "; ".join(errs)); sys.exit(1)
print(f"ok {m['id']} v{m['version']}")
PY
