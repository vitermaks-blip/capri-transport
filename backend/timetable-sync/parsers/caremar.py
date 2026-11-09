"""Parse Caremar Napoli–Capri timetables from easy.caremar.it (HTML, no API)."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date
from typing import Iterable

import requests

CAREMAR_URL = "https://easy.caremar.it/en/route-timetable/Napoli-Capri/"
USER_AGENT = "CapriTransportTimetableSync/1.0 (+https://github.com/maksym-viter/capri-transport)"

TIME_RE = re.compile(r"(\d{1,2}:\d{2})\s*-\s*\d{1,2}:\d{2}")
H2_SPLIT = re.compile(r"<h2[^>]*>", re.I)
SEASON_RE = re.compile(r"from\s+([^<\"]+)", re.I)


@dataclass(frozen=True)
class CaremarLeg:
    direction: str  # napoli-capri | capri-napoli
    season_label: str
    times: tuple[str, ...]


def _norm_time(t: str) -> str:
    h, m = t.split(":")
    return f"{int(h):02d}:{int(m):02d}"


def _in_caremar_season(label: str, when: date) -> bool:
    """Rough match for Caremar 'from X to Y' season headers."""
    low = label.lower()
    m, d = when.month, when.day
    md = m * 100 + d

    # winter: 1 Jan – 31 Mar and 4 Nov – 31 Dec
    if "january" in low and "march" in low and "november" in low:
        return md <= 331 or md >= 1104
    # summer: April 1 – November 3
    if "april" in low and "november" in low:
        return 401 <= md <= 1103
    return True


def _parse_sections(html: str) -> list[tuple[str, str, list[str]]]:
    out: list[tuple[str, str, list[str]]] = []
    for part in H2_SPLIT.split(html)[1:]:
        title_m = re.match(r"([^<]+)", part)
        if not title_m:
            continue
        title = title_m.group(1).strip()
        season_m = SEASON_RE.search(part)
        season = (season_m.group(1).strip() if season_m else "")[:120]
        times = [_norm_time(m.group(1)) for m in TIME_RE.finditer(part)]
        if times:
            out.append((title, season, times))
    return out


def fetch_caremar_napoli_capri(when: date | None = None, timeout: float = 30) -> dict[str, list[str]]:
    """
    Returns { 'napoli-capri': [times], 'capri-napoli': [times] } for the active season.
    """
    when = when or date.today()
    resp = requests.get(CAREMAR_URL, headers={"User-Agent": USER_AGENT}, timeout=timeout)
    resp.raise_for_status()
    sections = _parse_sections(resp.text)

    def pick(direction_sub: str) -> list[str]:
        for title, season, times in sections:
            if direction_sub not in title.lower():
                continue
            if _in_caremar_season(season, when):
                return times
        return []

    return {
        "napoli-capri": pick("naples - capri"),
        "capri-napoli": pick("capri - naples"),
    }
