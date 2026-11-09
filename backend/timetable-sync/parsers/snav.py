"""Parse SNAV Napoli Beverello–Capri times from public HTML (orari-e-tratte)."""

from __future__ import annotations

import re
from datetime import date

import requests

SNAV_URL = "https://www.snav.it/en/orari-e-tratte"
USER_AGENT = "CapriTransportTimetableSync/1.0 (+https://github.com/maksym-viter/capri-transport)"
TIME_RE = re.compile(r"\b(\d{1,2}:\d{2})\b")


def _norm_time(t: str) -> str:
    h, m = t.split(":")
    return f"{int(h):02d}:{int(m):02d}"


def _times_from_chunk(chunk: str) -> list[str]:
    raw = [_norm_time(m.group(1)) for m in TIME_RE.finditer(chunk)]
    if not raw:
        return []
    # Page lists two seasonal columns back-to-back — use the first half, then unique.
    half = max(1, len(raw) // 2)
    first_col = raw[:half]
    return sorted(set(first_col), key=lambda s: (int(s[:2]), int(s[3:])))


def fetch_snav_napoli_capri(timeout: float = 45) -> dict[str, list[str]]:
    """
    Returns { 'napoli-capri': [times], 'capri-napoli': [times] } (Fast Ferry block).
    SNAV uses footnote symbols per season; v1 takes the first timetable column only.
    """
    resp = requests.get(SNAV_URL, headers={"User-Agent": USER_AGENT}, timeout=timeout)
    resp.raise_for_status()
    html = resp.text
    start = html.find("NAPLES BEVERELLO - CAPRI")
    if start < 0:
        raise RuntimeError("SNAV: block NAPLES BEVERELLO - CAPRI not found")
    mid = html.find("Capri - Naples Beverello", start)
    if mid < 0:
        mid = html.find("Capri - Naples", start)
    end = html.find("SORRENTO - CAPRI", start)
    if mid < 0 or end < 0:
        raise RuntimeError("SNAV: could not bound Napoli–Capri section")

    outbound = html[start:mid]
    inbound = html[mid:end]
    return {
        "napoli-capri": _times_from_chunk(outbound),
        "capri-napoli": _times_from_chunk(inbound),
    }
