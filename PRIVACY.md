# Privacy

All editions of Stillgarden have no account system, advertisements, analytics, telemetry or cloud synchronization. It does not make network requests for weather, seasons or sound. All are local simulations or bundled assets.

The app saves plant locations/types/ages, accumulated snow, wildlife progress and settings to `~/Library/Application Support/Stillgarden/garden.json`. Reset writes a recoverable snapshot to `before-reset.json` in the same directory. The save includes timestamps to calculate offline progress. Window placement may also be saved by macOS.

Clicking the Paradoxical Software website link opens your browser. That website has its own privacy policy. GitHub hosts this repository, release downloads and the project website, under GitHub's own policies.

To remove all local garden data, quit the app and remove the Stillgarden folder from Application Support. Uninstalling the app alone does not remove your save. Do not publish a save file without reviewing it.

## Windows, Linux and web

Windows/Linux save a portable garden and undo snapshot in `garden-portable.json` inside Electron’s per-user application-data directory (typically `%APPDATA%/Stillgarden` on Windows and `$XDG_CONFIG_HOME/Stillgarden` or `~/.config/Stillgarden` on Linux). The web edition saves the same information in localStorage under the GitHub Pages origin. Export deliberately downloads a JSON file; import reads only the file you choose. There is no sync service.

The web app fetches its code, artwork and compressed audio from GitHub Pages and caches them for offline use. GitHub receives normal hosting requests under its privacy policy. There are no third-party trackers or remote fonts. Clearing the site's storage removes the web garden, undo copy and offline cache; export first if you want to keep it. Desktop editions bundle assets and need no network access.
