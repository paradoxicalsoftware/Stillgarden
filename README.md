<p align="center"><img src="docs/assets/banner.svg" alt="Stillgarden — a little room to breathe" width="960"></p>

<p align="center">
  <a href="https://github.com/paradoxicalsoftware/Stillgarden/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/paradoxicalsoftware/Stillgarden?color=41654b&label=download"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-41654b"></a>
  <img alt="macOS 13 or later" src="https://img.shields.io/badge/macOS-13%2B-41654b">
  <a href="https://github.com/paradoxicalsoftware/Stillgarden/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/paradoxicalsoftware/Stillgarden?style=flat&color=b58a42"></a>
</p>

<p align="center"><b>A living garden above your desktop. A small invitation to pause.</b><br>
Free, open source, and made with care by <a href="https://paradoxicalsw.com">Paradoxical Software</a>.</p>

<p align="center"><a href="https://paradoxicalsoftware.github.io/Stillgarden/">Explore the garden</a> · <a href="https://github.com/paradoxicalsoftware/Stillgarden/releases/latest">Download for Mac</a> · <a href="CONTRIBUTING.md">Help it grow</a></p>

<p align="center"><img src="docs/assets/day.png" alt="Stillgarden's illustrated clearing with daisies, lavender, cosmos, sunflowers, tulips and cornflowers" width="720"></p>

## A labor of love

Stillgarden began with a simple wish: make a small green space that can stay with you while you work. Plant a flower. Watch a butterfly settle for the night. Let the rain pass. There is nothing to win and no streak to protect.

We're sharing it freely in support of mental health and the everyday practice of making room for a pause. This is a personal, creative project—not a medical product or a substitute for care. Take what feels helpful, mute what doesn't, and make the garden your own.

**If this little garden makes your desktop feel kinder, give it a star.** It helps other people find it, and helps us see that this kind of software matters to someone.

## Your own small world

- **A garden that stays close.** Pin it above other apps. Hide every control; hover an edge to bring them back. Optional gentle visits fade the garden away and return it later.
- **Flowers with room to grow.** Ten varieties with distinct petals, leaves, stems and branching. Speed up a single plant, bloom it instantly, or let it grow in its own time.
- **A living habitat.** Bees turn with their flight. Caterpillars become cocoons and butterflies. Pollinators rest overnight and wake gradually at dawn.
- **Daylight at your pace.** Follow your Mac's clock, hold a chosen hour, or run an accelerated day. Light, stars and sound change smoothly.
- **Weather with a little wonder.** Calm breezes, windy spells, rain, branching lightning and individually delayed thunder. Seasons follow the calendar or your choice.
- **Winter that lingers.** Snow settles on the ground and flowers, stays in the cold, and gradually melts as conditions warm—even across restarts.
- **Sound you control.** Seasonal birdsong, crickets, a real owl call, rain and wind. Mute everything or choose a comfortable volume.
- **A fresh start, safely.** Reset the garden while keeping your settings. Undo the last reset, including after reopening the app.

**A small secret:** triple-click the open sky for **God mode**. Change time, weather and season, or give your plants a little extra time to grow.

| After dark | A winter pause |
| --- | --- |
| ![Night garden with sleeping pollinators and moonlight](docs/assets/night.png) | ![Snow accumulating on the ground and flower heads](docs/assets/winter.png) |

<details><summary>See the planting controls</summary>

![Stillgarden with its planting and growth controls visible](docs/assets/controls.png)

</details>

*Gallery images are rendered from the app's actual SwiftUI views with staged gardens, not mockups. Your garden will grow differently.*

## Download and open

1. Get **Stillgarden-1.0.0-macOS-universal.zip** from [Releases](https://github.com/paradoxicalsoftware/Stillgarden/releases/latest).
2. Unzip it and move **Stillgarden.app** to Applications.
3. Open it, choose a seed, and click the moss to plant.

**Requirements:** macOS 13 Ventura or later. The universal download includes Apple silicon and Intel builds. The release has been run on Apple silicon; Intel is cross-compiled but not yet tested on Intel hardware.

**First-launch note:** this community release is ad-hoc signed and is **not Apple-notarized**. macOS may block it. Review the source and release checksum, then follow [Apple's guidance for opening trusted software](https://support.apple.com/en-us/102445), or build it yourself below. We do not ask you to disable Gatekeeper or run a security-bypass command.

No account. No ads. No analytics. The app runs locally. Website links open only when you click them. [Privacy details](PRIVACY.md).

## Build from source

Install Xcode Command Line Tools and use a current Swift toolchain (Swift 6 recommended; release built with Swift 6.3).

```sh
git clone https://github.com/paradoxicalsoftware/Stillgarden.git
cd Stillgarden
./scripts/build.sh           # Build for this Mac
./scripts/test.sh
open build/Stillgarden.app
```

For a universal release:

```sh
./scripts/build.sh universal
./scripts/test.sh
./scripts/package.sh
```

No third-party Swift packages are required. The app uses AppKit, SwiftUI and AVFoundation. Included audio assets play without Python; regenerating synthesized audio requires Python, NumPy and macOS `afconvert`.

The save file lives at `~/Library/Application Support/Stillgarden/garden.json`. Reset creates `before-reset.json` in the same directory. Don't put either file in an issue or commit unless you've reviewed its contents.

## Help this garden grow

Bug reports, accessibility improvements, botanical details, thoughtful sound design and small contributions are welcome. You do not need to be an expert. Start with the [contribution guide](CONTRIBUTING.md), [roadmap](ROADMAP.md), and [Code of Conduct](CODE_OF_CONDUCT.md).

A useful first contribution might be testing on an Intel Mac, improving keyboard access, or explaining where a flower's growth feels wrong. Please open an issue before a large redesign. We want to keep the app calm, understandable and lightweight.

## Made by Paradoxical Software

We build useful software with curiosity and care. Stillgarden is our public, open-source labor of love.

**[Visit paradoxicalsw.com →](https://paradoxicalsw.com)**

Code and original project assets are available under the [MIT License](LICENSE). The recorded owl call is CC0. See [credits and asset provenance](CREDITS.md). Development was AI-assisted; the painted backdrop is AI-generated, while flowers and animation are drawn procedurally in SwiftUI.
