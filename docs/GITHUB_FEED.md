# Live timetable feed on GitHub

The app loads **`api/routes.json`** from:

`https://raw.githubusercontent.com/maksym-viter/capri-transport/main/api/routes.json`

(configured in `AppInfo.plist` → `CapriTimetableFeedURL`).

## One-time setup

1. Create (or use) GitHub repo **`maksym-viter/capri-transport`** with branch **`main`**.
2. Add a second remote on your machine:

   ```bash
   git remote add github https://github.com/maksym-viter/capri-transport.git
   ```

3. Push **`main`** (must include `api/routes.json` at repo root):

   ```bash
   git push -u github main
   ```

4. Verify in a browser:

   `https://raw.githubusercontent.com/maksym-viter/capri-transport/main/api/routes.json`

## Automated updates

- **Origin** (Cursor): `timetable-sync.yml` commits Caremar/SNAV data weekly.
- Mirror to GitHub after each sync:

  ```bash
  git push github main
  ```

  Or add GitHub Actions on GitHub that pulls from Origin, or use repo secret `GITHUB_MIRROR_URL` in a custom workflow.

## Local refresh

```bash
pip install -r backend/timetable-sync/requirements.txt
python backend/timetable-sync/sync.py --write api/routes.json --also-bundle
git add api/routes.json "Capri Transport/Schedule/routes.json"
git push origin main && git push github main
```
