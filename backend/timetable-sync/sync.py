#!/usr/bin/env python3
"""
Merge Caremar + SNAV scraped times into Capri Transport routes.json (same schema as the iOS app).

Usage (from repo root):
  python3 backend/timetable-sync/sync.py
  python3 backend/timetable-sync/sync.py --write api/routes.json --also-bundle
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent))

from parsers.caremar import fetch_caremar_napoli_capri
from parsers.snav import fetch_snav

ROME = ZoneInfo("Europe/Rome")
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BASE = REPO_ROOT / "Capri Transport" / "Schedule" / "routes.json"
DEFAULT_OUT = REPO_ROOT / "api" / "routes.json"


def _merge_op_departures(route: dict, operator: str, times: list[str]) -> None:
    deps = route.get("departures") or []
    kept = [d for d in deps if d.get("op") != operator]
    added = [{"time": t, "op": operator} for t in times]
    merged = kept + added
    merged.sort(key=lambda d: d["time"])
    route["departures"] = merged


def apply_operators(catalog: dict, caremar: dict[str, list[str]], snav: dict[str, list[str]]) -> None:
    by_id = {r["id"]: r for r in catalog.get("routes", [])}

    pairs = [
        ("napoli-capri", "ship-nap-cap", "Caremar", caremar),
        ("napoli-capri", "ship-nap-cap-hyd", "SNAV", snav),
        ("capri-napoli", "ship-cap-nap", "Caremar", caremar),
        ("capri-napoli", "ship-cap-nap-hyd", "SNAV", snav),
        ("sorrento-capri", "ship-sor-cap", "SNAV", snav),
        ("capri-sorrento", "ship-cap-sor", "SNAV", snav),
    ]
    for leg_key, route_id, operator, source in pairs:
        times = source.get(leg_key) or []
        if times and route_id in by_id:
            _merge_op_departures(by_id[route_id], operator, times)


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync Caremar/SNAV into routes.json")
    parser.add_argument("--base", type=Path, default=DEFAULT_BASE, help="Source catalog JSON")
    parser.add_argument("--write", type=Path, default=DEFAULT_OUT, help="Output path")
    parser.add_argument(
        "--also-bundle",
        action="store_true",
        help="Also overwrite Capri Transport/Schedule/routes.json",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print summary only, do not write")
    args = parser.parse_args()

    if not args.base.is_file():
        print(f"Missing base catalog: {args.base}", file=sys.stderr)
        return 1

    today = datetime.now(ROME).date()
    print(f"Sync date (Europe/Rome): {today.isoformat()}")

    caremar = fetch_caremar_napoli_capri(when=today)
    snav = fetch_snav()
    print(f"Caremar Napoli→Capri: {len(caremar.get('napoli-capri', []))} departures")
    print(f"Caremar Capri→Napoli: {len(caremar.get('capri-napoli', []))} departures")
    print(f"SNAV Napoli→Capri: {len(snav.get('napoli-capri', []))} departures")
    print(f"SNAV Capri→Napoli: {len(snav.get('capri-napoli', []))} departures")
    print(f"SNAV Sorrento→Capri: {len(snav.get('sorrento-capri', []))} departures")
    print(f"SNAV Capri→Sorrento: {len(snav.get('capri-sorrento', []))} departures")

    catalog = json.loads(args.base.read_text(encoding="utf-8"))
    readme = catalog.get("_readme", "")
    catalog["_readme"] = (
        readme.split("\n")[0]
        + f" | Synced Caremar/SNAV {today.isoformat()} (backend/timetable-sync)."
    )
    catalog["dataUpdated"] = today.isoformat()
    apply_operators(catalog, caremar, snav)

    if args.dry_run:
        print("Dry run — not writing files.")
        return 0

    out_text = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    args.write.parent.mkdir(parents=True, exist_ok=True)
    args.write.write_text(out_text, encoding="utf-8")
    print(f"Wrote {args.write}")

    if args.also_bundle:
        bundle_path = REPO_ROOT / "Capri Transport" / "Schedule" / "routes.json"
        bundle_path.write_text(out_text, encoding="utf-8")
        print(f"Wrote {bundle_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
