# TestFlight checklist (Capri Transport)

## Prerequisites

- Apple Developer account (Team ID configured in Xcode).
- **Bundle ID**: `com.taptap.Capri-Transport`
- **Widget**: `com.taptap.Capri-Transport.widget`
- **App Group** on both targets: `group.com.taptap.Capri-Transport`

## Signing (Xcode)

1. Target **Capri Transport** → Signing & Capabilities → Team → Automatic.
2. Target **Capri TransportWidget** → same Team + App Group.
3. Confirm **Capri Transport** embeds the widget (`Embed Foundation Extensions`).

## Device smoke (before archive)

| Check | How |
|-------|-----|
| Online feed | Wi‑Fi on → Schedule → ↻ → source shows online |
| Compare operators | Napoli ↔ Capri → two cards (cat / hydro) |
| Star + widget | Star route → home screen widget added |
| Live Activity | Star route → Lock Screen / Dynamic Island (iOS 17+) |
| Sights / landmarks | Landmarks filter → Apple Maps buttons |
| Support | About (ℹ️) → `support.oraricapri@gmail.com` |

## Archive

```bash
cd "/Users/maksymviter/app Capri Transportù/App Capri Transport/Capri Transport"
xcodebuild -scheme "Capri Transport" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/CapriTransport.xcarchive \
  archive
```

In Xcode: **Product → Archive** (scheme **Capri Transport**, device **Any iOS Device**).

## Upload

**Organizer** → Distribute App → **App Store Connect** → Upload.

Or:

```bash
xcodebuild -exportArchive \
  -archivePath build/CapriTransport.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

(`ExportOptions.plist` uses `method: app-store`.)

## App Store Connect

Paste metadata from `appstore/` (EN + IT). Set:

- **Support URL**: `mailto:support.oraricapri@gmail.com` or a simple landing page
- **Privacy**: no tracking; timetable feed from GitHub raw URL (see Privacy manifest if you add one later)
- **Age**: 4+
- **Category**: Travel

## CI reference

GitHub Actions `iOS` workflow should be green on `main` before you upload.
