<p align="center"><img src="docs/assets/app-icon.svg" width="112" alt="Songcrumb’s bitten-record icon"></p>
<h1 align="center">Songcrumb</h1>
<p align="center"><strong>Keep the words close.</strong><br>A little room for music on your Mac.</p>

Your music has something to say. Songcrumb keeps a few lines in view while you do your thing: a native macOS menu bar app that automatically finds lyrics and lets them follow the song.

Its compact panel sits flush beneath the menu bar, with monospaced type, a bright current line and quietly faded context. Let it stay there, or switch to a floating overlay. Lock it and your clicks pass straight through to the app underneath.

**macOS 14+ · Apple Silicon · SwiftUI + AppKit · No third-party Swift dependencies**

## What it does

- Reads Spotify and Apple Music desktop playback through public Apple Events. Sources are opt-in; it never launches a music player or changes playback.
- Connects to a YouTube Music tab through the included, paired Chrome / Edge / Brave companion. This integration is experimental and depends on the page’s player metadata.
- Finds the recording online through LRCLIB: exact lookup, then a bounded fallback search that checks artist, title, version and duration. No manual lyric files needed.
- Follows line timestamps when available. Plain text stays explicitly unsynced; unavailable lyrics get an honest status. It doesn’t invent timing or extract your player’s licensed lyrics.
- Offers typeface, size, highlight, transparency, width, context and timing controls. A nonactivating panel keeps keyboard focus with your work.
- Slows polling when idle or in Low Power Mode and pauses work during display sleep. M5 battery performance has not been benchmarked.

## Build and run

Open **Songcrumb.xcodeproj**, select **Songcrumb → My Mac**, and Run. The project targets arm64 with local ad-hoc signing. For a stable Automation identity, configure your own Apple Development team.

Or use Apple’s Command Line Tools:

```sh
./Scripts/build.sh
open build/Songcrumb.app
```

On first launch, use **Preview overlay** for original sample text. Then enable the music apps you use in Settings and allow their macOS Automation prompts. Online lookup is already configured with this project’s GitHub URL. **No personal email or account is needed.**

For YouTube Music, load **YouTubeMusicCompanion/** as an unpacked Chromium extension, enable the companion in Songcrumb, and pair using the token from Settings. See the [full setup guide](docs/SETUP.md) for steps and troubleshooting.

## A few practical limits

This is a source/developer release, not a notarized one-click installer. Public distribution of a signed binary needs Developer ID signing and notarization. The app’s use of public APIs does not guarantee layering over every full-screen or system-owned surface.

LRCLIB is community supplied. A matching API response does not establish a copyright licence for every lyric, and coverage or timing may be wrong. Use content you have rights to display. A licensed HTTPS backend adapter is included for agreements that support this overlay; details are in [Setup](docs/SETUP.md). No commercial lyrics, cookies, private player APIs or provider keys are bundled.

Live Spotify / Music / YouTube Music playback, permission prompts and M5 energy use still need manual validation. [Verification](VERIFICATION.md) states exactly what passed and what remains untested.

## Explore the project

- [Project page](docs/index.html) — original Songcrumb artwork and an interactive desktop illustration; open locally or serve `docs/`.
- [Setup and architecture](docs/SETUP.md) — supported players, provider contract, permissions and primary API references.
- [Privacy](PRIVACY.md) and [security](SECURITY.md) — what leaves the Mac and how the local bridge is constrained.
- `Songcrumb/Core/` — playback, matching, LRC parsing and bridge validation.
- `Songcrumb/App/` — SwiftUI, the attached/floating panel and native adapters.
- `YouTubeMusicCompanion/` — inspectable browser bridge, with no build step.

Run `./Scripts/test.sh` for native core/provider checks, a real loopback integration test and browser-companion fixtures. Node.js is required for the companion checks. Full Xcode also supports `swift test` for the shared core suite. Regenerate project file lists with `python3 Scripts/generate_project.py` when adding native source files.

Made by **Akshat Dhabi** for the songs between everything else.

[MIT licensed](LICENSE). The licence covers this code and original artwork/demo text; it grants no rights to third-party song lyrics or player trademarks.
