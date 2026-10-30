# Platform support

Stillgarden 1.1 adds Windows, Linux and the web alongside the original native Mac app.

| Platform | Distribution | Window behavior |
| --- | --- | --- |
| macOS 13+ · Apple silicon / Intel | Native SwiftUI universal ZIP | Pin above apps, hover-edge controls, gentle visits, menu bar |
| Windows 10/11 · x64 | Electron desktop installer | Pin above apps, hover-edge controls, gentle visits, tray |
| Linux · x64 | AppImage and Debian/Ubuntu `.deb` | Floating window on X11; Wayland placement is controlled by the compositor |
| Modern desktop/mobile browser | [Open the garden](https://paradoxicalsoftware.github.io/Stillgarden/play/) | Garden in a tab or installed web app; no system-wide pinning |

Windows and Linux share the same Canvas renderer and JavaScript simulation as the web edition. The original SwiftUI renderer remains on Mac. All editions include ten flower types, branching growth, insect lifecycles, nighttime rest, smooth lighting, simulated weather, seasonal sound, snow accumulation/melting, and reset with undo. Visual details can differ between renderers.

## Install

Download assets from the [latest release](https://github.com/paradoxicalsoftware/Stillgarden/releases/latest).

- **Windows:** run the `Windows-x64-Setup.exe` installer. This community build is unsigned; Windows may show an unknown-publisher warning.
- **Linux AppImage:** mark the file executable in your file manager, then open it. AppImage requires a compatible glibc environment and may require FUSE 2. On Ubuntu/Debian, the `.deb` is an alternative that can be opened in your package installer.
- **Linux `.deb`:** install with your distribution's package manager. It resolves the declared dependencies. The package is built on Ubuntu 24.04; other distributions have not been manually verified.
- **Mac:** unzip the universal app and move it to Applications. This release is ad-hoc signed and not Apple-notarized.
- **Web:** open the garden in a current browser. Choose **Sound off** to enable audio. A previously enabled soundscape can be resumed with **Start sound** after reopening. The app caches its code, artwork and audio for offline use after the first successful load; clearing site data removes both the cache and saved garden.

On Wayland, the app does not pretend to offer an unavailable pin toggle. Use your compositor's window rules or “Keep above” option if offered. Desktop Rest can be reversed from the tray or by launching the app again. Web Rest affects only the tab; browsers may throttle background timers. On touch devices, tap the garden to reveal controls. Keyboard users can press Tab to reveal controls and use the plant list and **Plant in clearing** button without clicking the canvas.

## Saves and moving devices

Windows/Linux store `garden-portable.json` in Electron's per-user application data directory. The web edition uses local browser storage under the project site's origin. Gardens remain separate unless you deliberately move one.

Use **Settings → Export garden** and **Import garden** to transfer a portable garden. Import also accepts the native Mac `~/Library/Application Support/Stillgarden/garden.json`, including its original timestamp format. Imports keep an undo copy; resetting also keeps one undo snapshot. There is no automatic cloud sync. Import into the native Mac edition is not currently exposed in its UI.

## Development

Node.js 22 or newer and npm are required for portable editions.

```sh
npm ci
npm test
npm start                  # Run desktop edition locally
npm run smoke:desktop      # Isolated throwaway save; does not touch your garden
npm run build:web          # Copy web/ into docs/play/ for GitHub Pages
npm run package:desktop -- --win --x64    # Run on Windows
npm run package:desktop -- --linux --x64  # Run on Linux
```

Serve `docs/` with a local HTTP server to develop the web edition; ES modules require HTTP(S), not opening `index.html` as a file. The service worker registers on HTTPS production deployments.

`web/model.js` contains the simulation and input validation; `web/render.js` draws the scene; `web/app.js` connects accessible controls, persistence and audio. `desktop/` is a sandboxed Electron host with a narrow preload bridge. It loads bundled resources through a local protocol, denies permissions and remote navigation, and opens only the two explicit project links externally. Desktop builds need no server or internet connection.

`npm run build:web` is deterministic; commit the generated `docs/play/` tree along with changes to `web/`. Compressed portable audio/artwork is generated from the credited originals with `scripts/encode-web-assets.sh`. The existing native build instructions remain in the main README.

## Validation boundaries

The simulation suite covers offline growth, snow retention and melting, day wrapping, reset/undo, save migration and malformed imports. GitHub Actions builds installers on Windows and Ubuntu and launches the packaged app to check renderer initialization, sandbox isolation, persistence and supported pinning. The web edition is exercised interactively on macOS. Native Intel Mac hardware and a broad range of Linux desktops have not been manually tested. Reports from these systems are welcome.
