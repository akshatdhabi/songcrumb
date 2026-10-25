# Security

## Scope

Songcrumb uses public AppKit, Foundation, Network and Apple Events APIs. It is a directly distributed, unsandboxed macOS app with hardened runtime and the Apple Events entitlement. Its protections limit network input; they do not isolate it from a compromised Mac, hostile process running as the same user, compromised browser, music app or lyrics provider.

## Boundaries

- Music apps are queried by running process ID, so polling cannot start an app that has exited. Event timeouts and per-read deadlines bound background work. No AppleScript source is assembled from song metadata.
- Lyrics requests require HTTPS without embedded username/password. Redirects must remain on the same HTTPS host and port. Responses are bounded to 512 KB; lyric data is rendered as plain text and never evaluated as code or HTML.
- The browser listener is disabled by default and binds only to 127.0.0.1. It exposes one metadata POST endpoint, no file access, playback control or arbitrary network forwarding.
- The parser enforces host, route, content type, content length and a bearer token. It rejects duplicate headers, transfer encoding, pipelined trailing data, ordinary website origins and invalid metadata. It caps request sizes, concurrent connections and read time.
- The extension’s destination is fixed. It checks sender identity, tab origin and permitted message keys. Content scripts cannot read the pairing token through storage.local. Cross-origin fetch omits cookies. Failed connections back off.
- No signing certificates, private keys or provider secrets belong in this repository. Tests use disposable synthetic tokens.

These controls are best-effort hardening, not a claim that all vulnerabilities have been eliminated. See VERIFICATION.md for test evidence and limits. Live services, macOS TCC, extension policies and display behavior require manual checks before describing a binary as a stable consumer release.

## Reporting

Do not put tokens, private listening data or exploit details into a public issue. Use GitHub private vulnerability reporting if the repository offers it. Otherwise open an issue asking the maintainer for a private reporting channel, without including the sensitive details.
