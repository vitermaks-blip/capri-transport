# Timetable sync (Caremar + SNAV)

Окремий бекенд **без офіційного API**: завантажує публічні HTML-сторінки перевізників і оновлює `routes.json` у форматі застосунку.

| Джерело | URL |
|---------|-----|
| Caremar | `https://easy.caremar.it/en/route-timetable/Napoli-Capri/` |
| SNAV | `https://www.snav.it/en/orari-e-tratte` (# Napoli–Capri) |

## Маршрути в каталозі

| `route.id` | Оператор |
|------------|----------|
| `ship-nap-cap` | Caremar (Napoli → Capri) |
| `ship-nap-cap-hyd` | SNAV (Napoli → Capri) |
| `ship-cap-nap` | Caremar (Capri → Napoli) |
| `ship-cap-nap-hyd` | SNAV (Capri → Napoli) |
| `ship-sor-cap` | SNAV (Sorrento → Capri) |
| `ship-cap-sor` | SNAV (Capri → Sorrento) |

Інші лінії (NLG, Medmar, автобуси ATC тощо) лишаються з базового `routes.json`.

## Локально

```bash
cd backend/timetable-sync
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python sync.py --dry-run
python sync.py --write ../../api/routes.json --also-bundle
```

## CI

Workflow `.github/workflows/timetable-sync.yml` — щотижневий dry-run парсерів, потім `api/routes.json` і `Capri Transport/Schedule/routes.json` (`--also-bundle`). Потрібен push на GitHub.

`ios.yml` → job `timetable-smoke` на кожен push/PR.

Застосунок підтягує `api/routes.json` з `CapriTimetableFeedURL` (GitHub raw).

## Обмеження

- Не live-статус рейсів і скасування в шторм.
- SNAV: на сторінці два сезонні стовпці — скрипт бере **перший** (v1); для точності по датах треба розшифрувати примітки `* ° ^ #`.
- Дотримуйся robots/ToS перевізників; користуйся помірною частотою (раз на добу/тиждень).
