# Verification — 25 October 2026

Environment: arm64 Mac, macOS 26.4.1, Swift 6.3.3 and Apple Command Line Tools. Full Xcode is not installed locally.

## Passed

- The native source set compiled for arm64-apple-macosx14.0 with SwiftUI, AppKit, Network and CryptoKit. The app was ad-hoc signed with hardened runtime and the Apple Events entitlement.
- The generated Xcode project parses as a property list and includes every Swift source, Info.plist, entitlements, icon and a shared scheme. Local direct compilation validates the source set; it is not a completed Xcode GUI build.
- The native original-text preview launched and displayed a compact top-attached panel, bright active lyric and faded context. The panel uses a nonactivating NSPanel; locked mode ignores mouse events.
- Core checks: 11 scenario groups covering timestamp parsing/offsets, seeks, explicitly unsynced text, malformed/simultaneous lines, stale/paused clocks, source selection, recording/version matching, identity collisions, HTTPS redirect policy, strict HTTP boundaries and attached geometry on notched/negative-coordinate display frames.
- Provider/preferences checks: 9 scenario groups using intercepted HTTP, including exact-to-search selection, caches, 429 backoff, setup-free GitHub client identity, plain-text fallback, preservation of plain lyrics when optional search fails, malformed timing recovery, licensed attribution/cache assertions and numeric sanitization. No requests reached an external service.
- Desktop adapter smoke check: parsed the installed Music scripting dictionary and constructed/coerced nested public Apple Event descriptors at runtime. No Apple Events were sent and no music app was started.
- Real loopback integration: 9 cases against the Swift listener on test-only 127.0.0.1:48538, including token, origin, routing, metadata and size rejection. Synthetic disposable metadata and token only.
- Companion syntax and fixtures: sender isolation, fixed destination, pairing, no cookie forwarding, active-tab ownership and player metadata extraction.
- Project page browser review: desktop and 390px narrow layout, attached/floating switch, highlight selection and original-text animation. The site has no remote runtime dependencies.

## Audit fixes included

Retained usable exact plain lyrics when optional search fails; rejected malformed timed text that previously displaced usable results; removed delimiter collisions in playback identity; restricted provider redirects; tightened loopback framing/host/origin checks; isolated browser token storage; added connection backoff; clamped stored preferences; restored unreachable floating panels; reduced unnecessary window ordering; added shutdown cleanup; replaced background NSAppleScript usage with direct Apple Events; removed all public email setup and bundled personal contact values.

## Still needs manual validation

- Real Spotify and Apple Music tracks: Automation allow/deny, pauses, seeks, transitions, app restarts, cloud/radio/incomplete metadata. Spotify is not installed locally.
- Signed-in YouTube Music in each supported browser: ads, background tabs, redesigns, local networking permissions, multiple tabs and suspension.
- A real authorized LRCLIB/provider recording, plus network failures on an ordinary network. Fixtures validate app behavior, not remote catalogue accuracy or display rights.
- Click-through focus behavior across real work apps, physical display removal, menu bar auto-hide, notch, Spaces, Stage Manager, full-screen and sleep/wake with live playback. Attached frame calculations are tested; all physical configurations are not.
- Full Xcode build/CI and optional Swift Package XCTest execution.
- Instruments energy and performance measurements on the user’s M5 MacBook Air.
- Developer ID signing, notarization and transferred-app Gatekeeper behavior before a consumer binary release.

Run Scripts/test.sh to reproduce the checks. Python 3 and Apple’s Command Line Tools are required; install Node.js for companion checks. Core XCTest checks also work with full Xcode selected. The Xcode app scheme has no XCTest bundle; use the supplied verification commands rather than assuming Product → Test covers these suites.
