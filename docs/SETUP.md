# Setup and implementation

A native macOS menu bar app that gives your music a small, quiet place on screen. Built in SwiftUI and AppKit, targeting **Apple Silicon, including M5 MacBook Air**, on **macOS 14 or later**. No third-party Swift dependencies, Electron, account, microphone access or audio capture.

The overlay is transparent, floats above ordinary app windows, passes clicks through when locked, and follows actual playback position. Line changes glide into place. It never becomes the key window or takes typing focus. Settings and file import open normal, interactive windows only when requested.

## Start here

The delivered `Songcrumb.app` is a locally signed arm64 developer build. The public app identifies itself to LRCLIB with the project’s GitHub URL. No personal email is bundled and no contact setup is needed. Open it, then use the **quotation-mark icon in the menu bar**. Settings opens on the first launch. Start with **Preview overlay** to see original sample text moving without connecting any service.

For your own music:

1. In **Settings → Music sources**, enable Spotify desktop, Apple Music desktop, or the YouTube Music companion.
2. Start a song in that source. Allow the per-app Automation prompt for Spotify or Music when it appears.
3. In **Lyrics & timing**, automatic internet lookup is already selected. No account or email is needed. After connecting a player, every song change looks up the right recording automatically; no local files or manual song searches are needed.
4. Use **Appearance** for font size, width, color, text opacity and backdrop opacity. Set backdrop opacity to zero for just floating text.
5. The default panel stays flush beneath the menu bar, with square top corners, rounded bottom corners and monospaced lyrics. **Unlock overlay controls** lets you scroll plain text or change settings. Choose **Floating** to drag the overlay anywhere; its position is saved separately. Lock it to restore click-through behavior. **Your overlay → Display** chooses a connected monitor by name. The menu bar has the same picker. The choice is saved by display UUID, falls back to the main screen while disconnected, and returns on reconnect. **Use pointer’s display** is a quick alternative.

Closing Settings leaves Songcrumb running in the menu bar. Choose **Quit** there to exit. Music connections are off by default. Automatic internet lookup is preselected, but requests only start after you connect a source.

## Compiled download

Use the [versioned Mac preview release](https://github.com/akshatdhabi/songcrumb/releases/tag/v1.0.0) for a DMG or ZIP that runs without Xcode. Open the DMG, drag Songcrumb to Applications and eject it. The ZIP contains the same app. Read [INSTALL.txt](INSTALL.txt) for the app-specific macOS approval steps and checksums. This preview is ad-hoc signed, not notarized; a local source build remains an alternative. The release includes an optional YouTube Music companion ZIP.

## Build and run in Xcode

1. Open `Songcrumb.xcodeproj` with Xcode 15 or later and a compatible macOS SDK. A current Xcode release is recommended for a current M5 Mac.
2. Select the **Songcrumb** scheme and **My Mac**. The project targets `arm64` only.
3. The project defaults to local ad-hoc signing. For a stable development identity, choose your own team and Apple Development signing in **Signing & Capabilities**. Use a unique bundle ID if you plan to distribute it.
4. Press **⌘R**. Connect music sources in the app.

The app deliberately uses the hardened runtime with the Apple Events entitlement and does **not** enable App Sandbox. This is a local/direct-distribution project, not an App Store submission. Sharing a polished release with other Macs requires your Developer ID signing, notarization and a distribution review of provider licensing. No certificate or private signing key is bundled.

Full Xcode is not necessary to build locally if Apple's Command Line Tools are installed:

```sh
cd /path/to/Songcrumb
./Scripts/build.sh
open build/Songcrumb.app
```

The build script creates a signed `.app` bundle with its usage descriptions, icon and entitlements. Rebuilding with ad-hoc signing can change how macOS remembers Automation approval; use a stable Apple Development identity if that becomes inconvenient. If macOS rejects an unnotarized copy transferred from elsewhere, build the source locally in Xcode instead.

## Music source support

| Source | Connection | Scope and practical limits |
| --- | --- | --- |
| Spotify | Desktop app's AppleScript interface | Reads track metadata, playback state and position. No Spotify Web API credentials. Browser Spotify, arbitrary Spotify Connect devices, ads and podcast timing are not guaranteed. |
| Apple Music | Music app's scripting dictionary | Reads the Music app's current track and clock. Library / subscription tracks work where the app exposes complete metadata. Radio and some cloud states can lack a usable track or duration. |
| YouTube Music | Included Chromium Manifest V3 extension | Reads the visible player bar and HTML media element in an open `music.youtube.com` tab. Requires pairing on this Mac. No private YouTube API, cookies, lyric extraction or media downloading. |

Automatic selection keeps the current source if it is playing. Otherwise it prefers a playing Spotify, then Music, then YouTube Music; if all are paused it keeps the current available source. Choose an explicit source when multiple apps play at once. Source toggles control whether that app is queried at all.

Desktop apps are queried through direct public Apple Events on a serial background queue with a bounded timeout. Property codes come from each installed app’s scripting dictionary. The main-thread-only `NSAppleScript` engine is not used. They are never launched or controlled by Songcrumb. Local music state is polled about once per second during playback, every three seconds when idle, and every two seconds while the overlay is hidden or Low Power Mode is on. Playback position is interpolated between samples, with a three-second extrapolation cap. Pauses and seeks reconcile on the next sample. Timing accuracy depends on the source and supplied recording; it is not sample-accurate karaoke.

### Set up YouTube Music

1. Use **Chrome, Edge or Brave** on the Mac where Songcrumb runs. Safari is not included; it needs separately packaged Safari extension work.
2. Open that browser's Extensions page: `chrome://extensions`, `edge://extensions` or `brave://extensions`.
3. Turn on **Developer mode**, choose **Load unpacked**, and select this project's **YouTubeMusicCompanion** folder. This is a local development extension, not a Web Store listing.
4. Enable **YouTube Music browser companion** in Songcrumb's Music sources settings.
5. Click **Copy pairing token** in Songcrumb. Open the extension popup, paste the token and select **Pair this browser**. Pin the extension if useful.
6. Open or reload `https://music.youtube.com`, start a song, and check the popup for **Connected to Songcrumb on this Mac**. Allow local-network access for the browser if macOS or the browser asks for it.

Pairing uses a randomly generated 64-character token and an HTTP listener **bound only to IPv4 `127.0.0.1:48537`**. No LAN listener is opened. Messages are authenticated, bounded in size, timed out and validated. Ordinary website origins are rejected; no CORS permission is advertised. The extension's service worker validates the sender and always posts to a fixed local address. It cannot forward arbitrary page-chosen URLs. Its token is stored in the extension's local storage, and the app's token in its local preferences. Reset pairing invalidates the old token; pair again afterward. The token authorizes playback metadata only and is not a Google credential.

The companion sends roughly one update per second while media events arrive, with a two-second discovery heartbeat. A second paused tab cannot take over an active tab. Ads detected through the page's ad state clear the song. Missing heartbeats expire after five seconds. DOM selectors, ad detection and background-tab scheduling are inherently best effort: a YouTube redesign, suspended tab, live stream, browser policy, incomplete artist metadata or delayed heartbeat can stop detection or prevent an exact lyrics match. Reload the tab and check the popup; if metadata is incomplete, automatic matching will show an unavailable state rather than guessing. Other YouTube desktop wrappers and the regular YouTube site are not integrated.

## Lyrics sources and rights

**Automatic internet lookup is the main workflow.** LRCLIB’s documented public API is preselected. Requests identify the app as `Songcrumb/1.0.0 (https://github.com/akshatdhabi/songcrumb)`. No listener email, account or API key is required.

On every recording change, Songcrumb:

1. Attempts a metadata lookup for the title, artist, album and duration.
2. If necessary, makes one bounded search request to recover from album differences or missing synced results.
3. Removes only presentation labels such as “Official Music Video” / “Official Audio”. It retains live, remix, acoustic and remaster labels, requires the artist names to match, and rejects duration differences above two seconds. Artist separator formatting can differ.
4. Ranks compatible recordings using duration and album, prefers synced lyrics, and caches the selected result for the session. It never blindly uses the first search hit or invents timing.

These checks reduce wrong-version matches; metadata alone cannot prove that a community-submitted lyric is correct. No confident match produces an honest unavailable state, and a ten-minute negative cache avoids repeated misses. **Fetch again** clears that cache and retries. Temporary network/429/500/502/503/504 failures schedule one cancellable automatic retry for the current recording, honoring Retry-After with positive jitter and increasing delays. Cooldowns are per HTTPS origin and survive Refresh; other recordings remain cached. Changing tracks, sleep, preview and quit cancel the pending retry. Status stays in the menu/settings or a calm waiting overlay, without alerts. If the source has no timed text, plain lyrics appear as unsynced text.

Lookup sends song metadata to LRCLIB. The app uses the documented API, identifies itself, serializes requests and honors backoff. Public access does not establish display rights for every community submission. Use content where you have the necessary rights; a commercial catalogue needs the relevant agreement. See the [provider's API documentation](https://lrclib.net/docs).

**A licensed provider can be connected through an HTTPS backend you control.** Choose **My licensed HTTPS provider**, enter its endpoint, and apply. Implement the contract below using a provider agreement that permits this display. Keep vendor keys on that backend. This project does not include a commercial lyrics agreement or falsely treat a provider response as proof of one. Licensed responses are not cached unless explicitly allowed by `allowSessionCache`.

Local import remains an optional override, not a requirement. Imports stay on the Mac in `~/Library/Application Support/Songcrumb/LocalLyrics` and are associated with the recording and source. Original preview lyrics are bundled for offline UI testing; no commercial lyrics are bundled.

Plain text is labeled **UNSYNCED** and scrolls manually while unlocked. Instrumental recordings get a quiet instrumental state. No match, missing metadata, rate limits and network errors get explicit status messages. Song changes trigger a fresh lookup automatically; Fetch again retries the current song. Positive timing adjustment shows lines earlier; it resets when the recording changes. Line sync is supported; word-level timing is not.

### Licensed backend contract

Songcrumb sends one HTTPS `GET` with `track_name`, `artist_name`, `album_name` and `duration` query parameters. Return `application/json` with this shape:

```json
{
  "trackName": "Exact title",
  "artistName": "Exact artist",
  "duration": 180,
  "instrumental": false,
  "syncedLyrics": "[00:02.00]Text you have display rights for",
  "plainLyrics": null,
  "attribution": "Required provider / publisher credit",
  "licenseConfirmed": true,
  "allowSessionCache": false
}
```

Title and artist must match after case/diacritic normalization and outer-whitespace trimming; duration must be within two seconds. Supply either LRC, plain text, or `instrumental: true`. Your backend must enforce the agreement's territory, expiry, attribution and display conditions. `licenseConfirmed` asserts those checks were done by your backend; the app cannot independently verify a licence. Use this adapter only for agreements compatible with this overlay and its displayed attribution. If a provider requires additional behavior, implement that before use. This is not a Musixmatch/Genius/Apple/Spotify account-token bypass.

Return 404 for no authorized match, 429 with `Retry-After` for backoff, or 503 for temporary unavailability. Retry-After supports seconds and an HTTP date. Requests time out and response bodies are limited to 512 KB. Automatic lookup performs at most an exact request plus one search per recording; there is no bulk lookup or unbounded retry loop. Session cache holds at most 30 recordings and is cleared by **Apply & reload** or quitting. Network lyrics are never saved to disk. Local imports are separate and persistent.

## Overlay, permissions and battery

The overlay uses public `NSPanel` / `NSWindow` APIs: a non-activating borderless panel, floating level, join-all-Spaces and full-screen auxiliary behavior, with mouse events ignored while locked. It cannot become key or main. Attached mode pins its backdrop to the chosen display’s physical top edge. Menu-bar and notch clearance is reserved inside the panel, so a hidden menu bar cannot leave an external gap or make lyric text jump. The panel remains below system menu-bar windows in window level. Floating mode restores its own saved position and clamps back to a connected display after screen changes. Line transitions respect Reduce Motion.

macOS full-screen apps, Stage Manager, other floating windows and system-owned UI can constrain layering. Songcrumb does not promise to cover every system surface, the lock screen, permission dialogs or protected content.

The only desktop playback permission is **Automation** for each enabled music app. Denial is surfaced without repeated prompts. Enable it under **System Settings → Privacy & Security → Automation**, then choose **Retry Automation**. Accessibility, Screen Recording, microphone and MusicKit subscription authorization are not requested. No private MediaRemote framework is linked.

The lyric view updates at up to five ticks per second while visible, playing and synced; normal line transitions animate briefly. Low Power Mode lowers the tick rate. Hidden, paused and unsynced views don't run that timeline. Display sleep cancels polling and requests, stops the browser listener and hides the overlay; waking reconnects. There is no high-frequency screen capture, audio analysis, artwork download or continuously running web renderer. These are efficiency choices, not a measured battery-life claim or an M5-specific benchmark.

## Verify and troubleshoot

Run the included checks with Command Line Tools, Python 3 and optionally Node.js:

```sh
./Scripts/test.sh
```

This runs shared Swift sync scenarios, automatic-provider fixtures with intercepted HTTP responses, integration checks against the real local Swift listener on test port 48538, and browser-companion syntax/fixture checks when Node is available. It uses test metadata and no external service. With full Xcode selected, `swift test` also runs the core scenarios through XCTest. The Xcode app scheme itself does not include an XCTest bundle.

If the overlay is missing: check **Show lyrics overlay**, disable **Hide while paused**, use **Reset position**, and try **Preview**. If one music source is selected explicitly, another source will not replace it. If updating from the running preview, quit that preview before opening the newly packaged app so the new lookup defaults take effect; your appearance settings are retained. If the bridge cannot bind, another Songcrumb instance or process may be using port 48537; quit duplicate instances and toggle the companion off/on. Browser policies can block unpacked extensions or local networking.

For wrong timings, first check whether the provider matched the correct version of the recording. Live, remastered and video versions often differ. Fetch again after checking the player metadata, or use the small timing adjustment for an otherwise correct recording. Missing or incorrect catalogue entries cannot be repaired by guessing timestamps. If lyrics are missing, the music app's own lyrics can still exist without being available to third-party apps. The public project URL is built in as the API client identity; there is no personal email or contact field.

For your own release, use Instruments' Energy Log / Time Profiler on your M5 with Spotify, Music and a background YouTube Music tab. Check pause/resume, seeks, changing songs, disconnection, sleep/wake, external displays, multiple Spaces and full-screen apps. See `VERIFICATION.md` for what was actually tested in the build environment.

## Research and implementation notes

Decisions and primary references, checked 25 October 2026:

- Spotify documents its macOS AppleScript integration in [Spotify Engineering](https://engineering.atspotify.com/2022/04/spotifys-player-api). Its staff confirms [there is no public lyrics API](https://community.spotify.com/t5/Spotify-for-Developers/Update-endpoint-for-lyrics/td-p/5355493). The app uses desktop scripting, not Web API scopes or internal color-lyrics endpoints.
- Music's installed dictionary, `/System/Applications/Music.app/Contents/Resources/com.apple.Music.sdef`, exposes `current track`, `player state`, `player position`, `duration` and `persistent ID`. Apple documents MusicKit's [`hasLyrics`](https://developer.apple.com/documentation/musickit/song/haslyrics) as a Boolean. The absence of a public lyrics-body retrieval API in the inspected MusicKit interface is why Songcrumb does not attempt to read Apple Music's licensed lyrics.
- [Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events), [NSPanel](https://developer.apple.com/documentation/appkit/nspanel), [`ignoresMouseEvents`](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents), and [`fullScreenAuxiliary`](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary) support the permission and overlay design.
- Google's documented [YouTube Data API resources](https://developers.google.com/youtube/data/reference/rest) provide no current YouTube Music tab playback endpoint. The [IFrame Player API](https://developers.google.com/youtube/iframe_api_reference) applies to players you embed, rather than an arbitrary signed-in music tab. The local browser companion is an explicit best-effort bridge around that limitation, not an official YouTube Music integration.
- Chrome's [extension network request documentation](https://developer.chrome.com/docs/extensions/develop/concepts/network-requests) informs the fixed-host background-worker bridge and sender validation. Only the companion reads page metadata. It has no lyrics or media-stream extraction code.

Source layout: `Songcrumb/Core` contains parsing, playback and selection logic; `Songcrumb/App` contains SwiftUI, the non-activating panel, serial Automation adapter, provider client and authenticated loopback server. `YouTubeMusicCompanion` is independently inspectable plain JavaScript. `Tests` and `Scripts` contain the verification tools.

- Apple documents the [main-thread restriction on NSAppleScript](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/ThreadSafetySummary/ThreadSafetySummary.html). Songcrumb sends Apple Events directly so polling does not block the UI. [NSScreen.visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe) supplies the usable display area for top attachment.
