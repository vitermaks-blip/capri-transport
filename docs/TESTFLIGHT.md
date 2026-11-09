# TestFlight checklist (Capri Transport)

## Швидкий старт (5 хвилин у Xcode)

1. Відкрий **`Capri Transport.xcodeproj`** (потрібен **Xcode 27+**).
2. Зверху обери **Capri Transport** scheme + **Any iOS Device (arm64)** (не симулятор).
3. Targets **Capri Transport** і **Capri TransportWidget** → **Signing & Capabilities** → свій **Team**, увімкни **Automatically manage signing**, перевір App Group `group.com.taptap.Capri-Transport` на обох.
4. **Product → Archive** → після збірки **Distribute App** → **App Store Connect** → **Upload**.
5. [App Store Connect](https://appstoreconnect.apple.com) → **TestFlight** → додай себе як тестера → встанови з TestFlight на iPhone.

Тексти для магазину: `appstore/en-US/metadata.md` та `appstore/it/metadata.md`.

**CI на GitHub:** зараз зелений **timetable-smoke**; повний `xcodebuild` на runner’ах чекає на Xcode 27 у CI (проєкт у форматі `project.xcproj`). Збирай на Mac перед релізом.

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
