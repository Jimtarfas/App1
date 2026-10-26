# Zapply: Big Button TV Remote

An easy-to-see iPhone remote for Roku, Samsung (Tizen) and LG (webOS) TVs, written in SwiftUI. It's built for people who find small remotes hard to use: large labeled keys, high contrast, spoken button names, Siri voice commands and one-tap routines.

- **Bundle ID:** `com.zapplyremote.app`
- **App Store Connect app:** 6826950199
- **Team:** ZUCC9R4PP4
- **Minimum iOS:** 17.0 (iPhone only)

## Features

- Finds TVs by probing the local /24 for each platform's control port (Roku 8060, Samsung 8001, LG 3000/3001). This only needs Local Network permission, not the multicast entitlement. You can also add a TV by IP address.
- Two layouts: **Big Buttons** (default; fewer, larger keys with word labels, in Standard/Large/Extra Large) and **Full Remote** (every control). See `Zapply/Views/RemoteView.swift` and `Zapply/App/RemotePreferences.swift`.
- High contrast keys and Speak Button Names (AVSpeechSynthesizer, silent while VoiceOver runs).
- Siri & Shortcuts: App Intents in `Zapply/App/ZapplyIntents.swift` (turn off, mute, volume up/down, press any button, open a TV app, run a routine).
- Routines: user-built step lists (press, open app, wait, type) in `Zapply/Routines/`. Free accounts keep 3.
- App launcher for each TV's installed apps.
- A Demo TV that draws a virtual screen, so every control can be tried without a TV (and by App Review).
- **Premium** (StoreKit 2, group "Zapply Premium"): phone keyboard, channel buttons and number pad, more than one saved TV, and unlimited routines.
  - `com.zapplyremote.app.premium.yearly`: $29.99 per year with a 3-day free trial (the app no longer offers the weekly product created in App Store Connect).

| Platform | Transport | Code |
|---|---|---|
| Roku | HTTP ECP on 8060 | `Zapply/TV/RokuController.swift` |
| Samsung | WebSocket `samsung.remote.control` on 8002 (TLS, token) or 8001 | `Zapply/TV/SamsungController.swift` |
| LG webOS | SSAP WebSocket on 3001 (TLS) or 3000, plus the pointer socket | `Zapply/TV/LGController.swift` |

## Build

```bash
xcodegen generate
open Zapply.xcodeproj
```

The Run scheme uses `StoreKit/Zapply.storekit` for local purchase testing. Keep archives and DerivedData outside `~/Desktop`, because codesign fails there; the release builds were made in `~/Developer/ZapplyBuild`.

## Store assets

- Listing text and review notes: `marketing/aso/app-store-listing.md`; draft reply to the 4.3/4.2.6 rejection: `marketing/aso/app-review-reply.md`
- Screenshots: `swift scripts/make-store-screenshots.swift marketing/screenshots/captions.json marketing/screenshots/raw marketing/screenshots` renders the 6.9" and 6.5" sets from raw captures.
- Debug-only launch arguments stage the captures: `-hasOnboarded YES -demo YES -premium YES`, `-sampleTVs YES -startTab tvs`, `-showPaywall upgrade`, `-buttonSize extraLarge -highContrast YES`, and `-autoplay YES` for the scripted walkthrough used in the App Review video (`marketing/video/zapply-demo.mp4`, not committed).
- App icon: `swift scripts/make-icon.swift Zapply/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`

## Website

`docs/` holds the landing page, privacy policy, support page and terms. Because this repo is private, the pages are published from the public repo `Jimtarfas/zapply-remote` to https://jimtarfas.github.io/zapply-remote/. Copy `docs/` there to update it.
