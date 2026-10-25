<p align="center">
  <img src="docs/assets/readme-header.svg" width="100%" alt="Songcrumb: keep the words close.">
</p>

<p align="center">
  A few lines from your music, right beneath the menu bar.<br>
  Native macOS. Automatic lyrics. A little room for your everyday soundtrack.
</p>

<p align="center">
  <a href="https://github.com/akshatdhabi/songcrumb/releases/download/v1.1.0/Songcrumb-1.1.0-arm64.dmg"><strong>Download for Mac ↓</strong></a>
  &nbsp; · &nbsp;
  <a href="https://github.com/akshatdhabi/songcrumb/releases/download/v1.1.0/Songcrumb-1.1.0-arm64.zip">ZIP</a>
  &nbsp; · &nbsp;
  <a href="docs/SETUP.md">Setup guide</a>
</p>

<p align="center"><sub>macOS 14+ · Apple Silicon (M1 and later) · v1.1 developer preview · MIT</sub></p>

<p align="center">
  <img src="docs/media/desktop-demo.gif" width="100%" alt="Illustrated Mac desktop with Songcrumb attached beneath the menu bar, scrolling and highlighting original demo lyrics.">
  <br><sub>Illustrated desktop with original demo lyrics.</sub>
</p>

## What it does

Play a song and Songcrumb finds its lyrics, then keeps three lines in view while you work. The current line glows and the rest fade back.

| | |
| :--- | :--- |
| **Stays out of the way** | Attach it beneath the menu bar or float it anywhere. Lock it and clicks pass through to the app below. |
| **Any screen** | Pick the monitor in Settings or the menu bar. It holds its place in full-screen apps and clears the camera notch. |
| **Follows the song** | Synced lyrics scroll on time. Songs without timestamps show plain text, marked as unsynced. |
| **Recovers on its own** | If the lyrics server hiccups, Songcrumb retries in the background. No alerts. |
| **Yours to style** | Typeface, size, highlight colour, opacity and width. |

## Works with

| Player | How it connects |
| :--- | :--- |
| Spotify | Desktop app, via macOS Automation |
| Apple Music | Desktop app, via macOS Automation |
| YouTube Music | Browser companion for Chrome, Edge or Brave (experimental) |

No account, no email, no API key, no analytics. Songcrumb reads the track details and playback position from your player, and sends the song's title, artist, album and duration to the lyrics lookup. It doesn't capture audio or your screen, and it doesn't save lyrics or listening history to disk.

## Install

1. **[Download the DMG](https://github.com/akshatdhabi/songcrumb/releases/download/v1.1.0/Songcrumb-1.1.0-arm64.dmg)** and drag Songcrumb into Applications.
2. **Open it.** The quotation-mark icon appears in your menu bar. Click **Preview overlay** to see it working before you connect anything.
3. **Connect your player** in Settings and allow the macOS Automation prompt.

**If macOS blocks the first launch:** this preview isn't notarized by Apple yet. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Songcrumb. The [install guide](docs/INSTALL.txt) has checksums and full steps.

YouTube Music needs the browser companion. Pairing takes a minute: see the [setup guide](docs/SETUP.md#set-up-youtube-music).

<details>
<summary><strong>Screenshots</strong></summary>

<br>
<p align="center"><img src="docs/media/attached-overlay.png" width="560" alt="The native Songcrumb overlay showing original preview lyrics."></p>

| Appearance | Music connections |
| :---: | :---: |
| ![Native appearance settings](docs/media/appearance.png) | ![Native music connection settings](docs/media/music-sources.png) |

Captured from the native app with original sample text and music connections off.

</details>

<details>
<summary><strong>Build from source</strong></summary>

Open **Songcrumb.xcodeproj** in Xcode, choose **Songcrumb → My Mac**, then Run. Set your own development team so macOS Automation permissions stick between builds.

Or build with Apple's Command Line Tools:

```sh
./Scripts/build.sh
open build/Songcrumb.app
```

SwiftUI and AppKit, arm64, zero third-party Swift dependencies. `./Scripts/test.sh` runs the native and browser-companion checks (the companion checks need Node.js). [VERIFICATION.md](VERIFICATION.md) lists what's tested and what still needs a manual pass.

</details>

## Where lyrics come from

Songcrumb looks up lyrics on [LRCLIB](https://lrclib.net), a free community database, or from a licensed provider you configure yourself. It matches on title, artist, album and duration, so coverage and timing depend on what the community has submitted. Songcrumb doesn't pull lyrics out of Spotify, Apple Music or YouTube Music. [Provider details →](docs/SETUP.md)

[Privacy](PRIVACY.md) · [Security](SECURITY.md) · [Verification](VERIFICATION.md) · [Release notes](docs/RELEASE-NOTES.md) · [Changelog](CHANGELOG.md)

Made by **[Akshat Dhabi](https://github.com/akshatdhabi)** for the songs between everything else.

<sub>[MIT licensed](LICENSE). Covers the code, artwork and demo text. Lyrics belong to their rights holders.</sub>
