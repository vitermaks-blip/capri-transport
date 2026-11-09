# GitHub Actions

Repo: [vitermaks-blip/capri-transport](https://github.com/vitermaks-blip/capri-transport)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **iOS** | push/PR `main` | Python smoke + Xcode build & unit tests |
| **Timetable sync** | Mon 05:00 UTC, manual | Caremar/SNAV → `api/routes.json` + bundle |

## Enable Actions

1. GitHub repo → **Actions** → enable workflows if prompted.
2. Push to `main` or run **Run workflow** on *Timetable sync*.

## Manual timetable sync

Actions → **Timetable sync** → **Run workflow**.

Commits only when times change (`github-actions[bot]`).

## Status

After push, open the **Actions** tab and confirm the latest **iOS** run is green (~10–15 min on `macos-15`).

Local equivalent:

```bash
python backend/timetable-sync/sync.py --dry-run
xcodebuild -scheme "Capri Transport" -destination 'generic/platform=iOS Simulator' build test
```
