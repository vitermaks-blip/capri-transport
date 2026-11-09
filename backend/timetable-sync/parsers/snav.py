"""Parse SNAV Napoli Beverello–Capri times from public HTML (orari-e-tratte)."""

from __future__ import annotations

import re
from datetime import date

import requests

SNAV_URL = "https://www.snav.it/en/orari-e-tratte"
USER_AGENT = "CapriTransportTimetableSync/1.0 (+https://github.com/vitermaks-blip/capri-transport)"
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


def _slice(html: str, start_marker: str, mid_markers: list[str], end_marker: str) -> tuple[str, str]:
    start = html.find(start_marker)
    if start < 0:
        raise RuntimeError(f"SNAV: block {start_marker!r} not found")
    mid = -1
    for marker in mid_markers:
        mid = html.find(marker, start)
        if mid >= 0:
            break
    end = html.find(end_marker, start)
    if mid < 0 or end < 0:
        raise RuntimeError(f"SNAV: could not bound {start_marker!r}")
    return html[start:mid], html[mid:end]


def fetch_snav(html: str | None = None, timeout: float = 45) -> dict[str, list[str]]:
    """
  Napoli + Sorrento blocks from one HTML fetch.
    Keys: napoli-capri, capri-napoli, sorrento-capri, capri-sorrento.
    """
    if html is None:
        resp = requests.get(SNAV_URL, headers={"User-Agent": USER_AGENT}, timeout=timeout)
        resp.raise_for_status()
        html = resp.text

    nap_out, nap_in = _slice(
        html,
        "NAPLES BEVERELLO - CAPRI",
        ["Capri - Naples Beverello", "Capri - Naples"],
        "SORRENTO - CAPRI",
    )
    sor_start = html.find("SORRENTO - CAPRI")
    if sor_start < 0:
        sor_start = html.find("Sorrento - Capri")
    sor_out, sor_in = ("", "")
    if sor_start >= 0:
        mid = html.find("Capri - Sorrento", sor_start)
        if mid < 0:
            mid = html.find("Capri - Sorrento", sor_start)  # same
        end = html.find("<h2", mid + 1) if mid >= 0 else -1
        if end < 0:
            end = len(html)
        if mid >= 0:
            sor_out, sor_in = html[sor_start:mid], html[mid:end]
    return {
        "napoli-capri": _times_from_chunk(nap_out),
        "capri-napoli": _times_from_chunk(nap_in),
        "sorrento-capri": _times_from_chunk(sor_out),
        "capri-sorrento": _times_from_chunk(sor_in),
    }


def fetch_snav_napoli_capri(timeout: float = 45) -> dict[str, list[str]]:
    """Backward-compatible: Napoli–Capri legs only."""
    full = fetch_snav(timeout=timeout)
    return {
        "napoli-capri": full.get("napoli-capri", []),
        "capri-napoli": full.get("capri-napoli", []),
    }
