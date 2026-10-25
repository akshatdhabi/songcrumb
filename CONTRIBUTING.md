# Contributing

Keep Songcrumb native, quiet and explicit about source limitations. Never add private player APIs, unauthorized lyric scraping, account-cookie extraction or embedded provider credentials.

Build with Scripts/build.sh and run Scripts/test.sh. Include a regression check for correctness or trust-boundary fixes. Use original or synthetic lyric fixtures. Update docs when permissions, network behavior or support changes. Regenerate the Xcode file lists with Scripts/generate_project.py when adding Swift files.

For UI changes, check attached and floating layouts, locked/unlocked states, unavailable/plain/synced lyrics and Reduce Motion. For adapter changes, state which real player versions and permission states were tested. Do not replace manual testing with claims based on fixtures.
