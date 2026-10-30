# Help Stillgarden grow

Thank you for considering a contribution. This is a small, independent project, and thoughtful contributions of any size are welcome. Please read our [Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

Check existing issues and pull requests. For a substantial feature or redesign, open a feature request first so we can discuss the experience and maintenance cost. We value calm defaults, user control, accessibility and local-first behavior. Avoid adding accounts, analytics, unsolicited notifications or new network dependencies without discussion.

You can help without writing code: report a reproducible bug, test an Intel Mac, review a flower's appearance, improve instructions, or suggest a better interaction for keyboard and assistive-technology users. Don't share personal health information in public issues.

## Development

1. Fork and clone the repository, then create a focused branch.
2. Build with `./scripts/build.sh` on macOS 13 or later using a current Swift toolchain.
3. Run `./scripts/test.sh`.
4. Open `build/Stillgarden.app` and test the behavior you changed.

`Sources/Stillgarden/main.swift` contains the model, procedural rendering and native app shell. `Resources/` contains packaged art and audio. `scripts/` contains builds, checks and asset generators. `docs/` is the GitHub Pages site.

Self-tests use an isolated save directory for destructive operations. Never test reset, migration or deletion against another person's real garden. Changes to saved data must decode older files and preserve an undo path where appropriate.

For rendering changes, check an early sprout, mature plant, snow-covered plant, day and night. For audio, test mute, volume changes, hiding the garden, and switching atmosphere. Describe checks you actually performed; do not imply a platform was tested if it was only cross-compiled.

## Pull requests

Explain the user-visible problem, what changes, and how you checked it. Include before/after screenshots for visible changes and a short audio sample or listening notes for sound changes. Keep unrelated cleanups separate. A small, reviewable change is easier to accept than a broad rewrite.

Do not commit build outputs, user saves, credentials, personal data or files copied from an unclear source. Document the provenance and license of every new asset. AI-assisted contributions are welcome when you understand, review and test the result; disclose meaningful generated assets and retain their provenance.

By submitting a contribution, you agree that your contribution is offered under this repository's MIT license, except for separately identified assets with compatible licenses. You retain credit for your work. No contributor agreement is required.

## What makes a good first contribution?

- Reproduce a bug and add clear steps.
- Test on Intel hardware and report the macOS version.
- Improve keyboard navigation or VoiceOver labels.
- Improve a specific flower's anatomy without increasing visual clutter.
- Add a focused test for a real persistence or timing edge case.

Maintainers may take time to respond. This is a labor of love, not a paid support contract. Kindness and clear context go a long way.
