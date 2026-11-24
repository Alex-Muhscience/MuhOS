# Contributing to MuhOS

Thanks for helping. MuhOS is maintained by Alex M. Kamau
([@Alex-Muhscience](https://github.com/Alex-Muhscience)), and contributions
of every size are welcome: a bug report from real hardware is as useful as a
pull request.

## Ways to help

- **Test on real hardware.** MuhOS has been tested in Fedora virtual
  machines. Reports from laptops and desktops, especially with NVIDIA, hybrid
  graphics or several monitors, are the most valuable thing right now. Post
  them in [Discussions → Show and tell](https://github.com/Alex-Muhscience/MuhOS/discussions)
  even when everything works.
- **Report bugs** with the [bug form](https://github.com/Alex-Muhscience/MuhOS/issues/new/choose).
  Include the shell log: `journalctl --user -u muhos-shell -b`.
- **Suggest features** in [Discussions → Ideas](https://github.com/Alex-Muhscience/MuhOS/discussions)
  first, so we can agree on the design before anyone writes code.
- **Translate.** Interface strings are in `src/assets/languages/*.json`.
- **Write code**: QML for the interface, Bash and Python for helpers, RPM
  packaging for Fedora.

## Getting in touch

- **Questions, ideas and "I'd like to work on X":** [GitHub Discussions](https://github.com/Alex-Muhscience/MuhOS/discussions).
- **Bugs:** [issues](https://github.com/Alex-Muhscience/MuhOS/issues).
- **Security problems:** please don't open a public issue; use
  [private vulnerability reporting](https://github.com/Alex-Muhscience/MuhOS/security/advisories/new).

Before starting on something big, open a discussion or comment on the issue
so we don't duplicate work, and so the change fits where MuhOS is going.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep each pull request to **one** feature or fix. Small, focused pull
   requests are reviewed faster and are far more likely to be merged.
3. Start every commit subject with a label (see [FORK.md](FORK.md)):

   | Label | For |
   |---|---|
   | `[general]` | Fixes and features that aren't Fedora- or MuhOS-specific; these may be offered upstream to Serpantinum |
   | `[fedora]` | Packaging, dependencies and session integration for Fedora |
   | `[brand]` | MuhOS names, logos and wording |
   | `[fork]` | Docs, website, tooling |
   | `[ci]`, `[bench]` | CI and lint baselines; benchmark reports |

   Keep `[general]` commits free of Fedora or branding changes.
4. Run the checks (they run in CI too):

   ```sh
   python3 -I tools/asset-inventory --strict   # every asset licensed
   python3 -I tools/lint-baseline --check      # lint findings must not grow
   ```

   and build and test the package in a Fedora 44 container as described in
   [Building and testing](README.md#building-and-testing).
5. If you change upstream Serpantinum files, run `bash tools/changes-from-upstream`
   in the same commit (it keeps the AGPL modification notice up to date).
6. Describe what you changed, why, and how you tested it. Screenshots help
   for anything visible.

## Ground rules

- **Evidence over claims.** No performance claim without a benchmark in
  `bench/results/`; describe what you tested, not what you expect.
- **Licences matter.** Every font, icon, sound and image needs a source and
  a licence compatible with redistribution (see [ASSETS.md](ASSETS.md)).
  Apple's own fonts, icons and wallpapers can't be used.
- **Respect upstream.** MuhOS is built on [Serpantinum](https://github.com/ilyamiro/serpantinum)
  by Illia Miroshnichenko; keep attribution and keep upstream merges cheap.
- **Be kind.** Assume good intent, keep discussions about the work, and help
  newcomers.

By contributing, you agree that your contribution is licensed under the
[AGPL-3.0-or-later](LICENSE.md), like the rest of MuhOS.
