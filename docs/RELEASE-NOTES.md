## New in 1.1.0

- Pick your monitor in the menu or **Settings → Your overlay → Display**. The choice survives restarts; disconnecting a monitor uses the main screen until it returns.
- Attached mode reaches the physical top edge in full screen, with a stable safe area for the menu bar and camera notch.
- Lyrics-server pauses recover automatically. Requests honor Retry-After and add jitter/backoff; refreshing keeps other songs cached and never bypasses a server cooldown.
- Redesigned settings with a sidebar, grouped controls and live typography preview; a smaller attached panel and calmer waiting state.

Songcrumb keeps the words close: a native macOS lyrics overlay, attached beneath the menu bar or floating wherever you like.

## Install without Xcode

**Apple Silicon · macOS 14+**

Download the **DMG**, open it, and drag **Songcrumb → Applications**. Open the app from Applications; its quotation-mark icon lives in the menu bar. A ZIP of the same compiled app is available as an alternative. The separate YouTube Music companion is optional.

**This is an ad-hoc signed developer preview, not notarized by Apple.** macOS may block the download. If you trust the project, follow the included INSTALL.txt and [Apple's Open Anyway guidance](https://support.apple.com/guide/mac-help/mh40616/mac). Building the source locally is another option. No instruction disables Gatekeeper or removes quarantine.

## Included

- Top-attached and floating panels, monospaced lyrics, click-through locking and appearance controls.
- Opt-in Spotify and Apple Music playback adapters, plus an experimental paired YouTube Music companion.
- Automatic LRCLIB recording lookup, timed/untimed/unavailable states and optional licensed backend support.
- Original branding, demo lyrics, real native screenshots, animated demo and MIT-licensed source.
- Compiled arm64 DMG and ZIP, companion ZIP, install guide and SHA-256 checksums.

## Known limits

Automated native, provider and bridge checks pass; live Spotify/Music/YouTube Music, permission behavior, physical display removal/reconnection, additional full-screen configurations and M5 energy measurements still require manual validation. Lyrics coverage and rights vary; no commercial lyrics are bundled. This is line sync, not word-level karaoke. Intel and Safari are not supported by this preview.

Checksums identify the uploaded bytes and help detect transfer corruption. They do not substitute for Developer ID signing, notarization or an independent security audit. See README, VERIFICATION.md and PRIVACY.md for details.
