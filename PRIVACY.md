# Privacy

Songcrumb has no account, analytics, crash upload, audio capture, screen capture or remote settings service. The project page has no trackers or remote fonts.

## Online lyrics

When a connected player supplies a new song, the default LRCLIB lookup sends its title, artist, album and rounded duration over HTTPS. LRCLIB also sees the network’s public IP address and the app identity: the public GitHub project URL. No personal email, music account token, browser cookie or pairing token is included. An optional licensed backend receives the same metadata instead. Its operator sets its own privacy policy; do not put credentials into the endpoint URL.

Network lyrics are held in a bounded memory cache and are not written to disk by the app. The HTTP session is ephemeral. Offline mode disables lyrics requests. Optional local overrides persist in the user’s Application Support folder.

## Playback and browser pairing

Enabled desktop sources expose track metadata and timing through per-app macOS Automation permission. Disabled sources are not queried. The browser companion reads only music.youtube.com’s player metadata and media clock. It sends them to the paired app at IPv4 127.0.0.1:48537, on the same Mac. It does not read lyric text, account cookies or media streams.

Pairing tokens and appearance preferences are saved locally. Tokens are not Google credentials. The extension restricts its local token storage to trusted extension contexts. Other processes running as the same macOS user are outside this isolation boundary; do not share the token. Reset pairing to invalidate it.

Quitting stops work and clears the memory lyrics cache. To remove retained settings, delete the app’s preference domain and the Songcrumb Application Support folder after quitting. This also removes optional imported overrides. macOS retains Automation decisions separately in System Settings.
