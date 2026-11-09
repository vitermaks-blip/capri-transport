#!/bin/sh
# Creates github.com/<your-user>/capri-transport and pushes main (requires gh auth).
set -e
cd "$(dirname "$0")/.."

if ! command -v gh >/dev/null 2>&1; then
  echo "Install GitHub CLI: https://cli.github.com/"
  exit 1
fi

gh auth status -h github.com

if git remote get-url github >/dev/null 2>&1; then
  echo "Remote github already set."
else
  gh repo create capri-transport --public --description "Capri Transport iOS — timetables & sights" --remote=github --confirm
fi

git push -u github main
echo "Feed URL: https://raw.githubusercontent.com/$(gh api user -q .login)/capri-transport/main/api/routes.json"
