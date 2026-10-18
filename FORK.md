# How MuhOS tracks upstream

MuhOS is a Fedora-focused downstream of
[Serpantinum](https://github.com/ilyamiro/serpantinum) by Illia Miroshnichenko.
This file describes how the fork is kept maintainable. Licensing and
attribution are in `NOTICE`; bundled asset status is in `ASSETS.md`.

## Target platform

| | |
|---|---|
| Distribution | Fedora 44 Workstation, x86_64 |
| Compositor | Hyprland only (Niri/Sway/Mango are kept in-tree but untested) |
| Login | GDM is kept; MuhOS is a session entry, never a display-manager replacement |
| Packaging | RPM from a MuhOS COPR. No `curl \| bash`, no telemetry |

## Branches and remotes

- `upstream` remote: `https://github.com/ilyamiro/serpantinum.git` (push disabled).
- `main`: MuhOS. Based on upstream release **tags** only, never upstream `master`.
- Current base: `v2.2.13` (`d6f1c8d`).

### Syncing to a new upstream release

```sh
git fetch upstream --tags
git switch -c sync/vX.Y.Z main
git merge --no-ff vX.Y.Z      # resolve conflicts, keep MuhOS changes minimal
tools/asset-inventory --check # new upstream assets must be classified
```

Then update `Based on` in `NOTICE` and the base tag above, run the test and
benchmark suites, and merge `sync/vX.Y.Z` into `main`.

## Labelling changes

Every MuhOS commit subject starts with exactly one label:

| Label | Meaning | Destination |
|---|---|---|
| `[general]` | A fix or improvement that is not Fedora- or MuhOS-specific | Offer upstream as a PR |
| `[fedora]` | Packaging, dependencies, paths or session integration for Fedora | MuhOS only |
| `[brand]` | MuhOS naming, logos, wording | MuhOS only |
| `[fork]` | Fork infrastructure: CI, tooling, docs like this one | MuhOS only |

Keep `[general]` commits free of `[fedora]`/`[brand]` changes so they can be
cherry-picked upstream cleanly. `CHANGES-FROM-UPSTREAM.md` is generated from
these labels.

## Modified-file notices

When MuhOS first changes an upstream file, add a header comment directly
below any existing license header:

```
// Modified by MuhOS, 2026-10-18. See NOTICE.
```

(Use the comment syntax of the file: `#` for shell, Python, TOML.)

## Branding

MuhOS ships its own identity:

- Product name **MuhOS**; commands `muhos` and `muhosd` (upstream:
  `serpantinum`, `serpantinumd`).
- Own logo, banner, screenshots and wallpapers. Everything marked
  `upstream-branding` in `ASSETS.md` gets replaced.
- Attribution stays visible: the About page and README say
  "Based on Serpantinum by Illia Miroshnichenko".
- Internal identifiers (QML ids, settings keys, state paths) are renamed only
  where users can see them, to keep upstream merges cheap.

## Evidence rules

- No performance claim without a benchmark run committed under `bench/results/`
  that compares against the unmodified upstream base tag.
- Lint baselines (`ci/lint-baseline.json`) may only go down.
- `tools/asset-inventory --strict` must pass before any release.

## Open decisions

- **Public history.** The upstream history contains non-redistributable fonts
  (see `ASSETS.md`). Pushing the full history to a public host
  redistributes them. Decide before the first push: either rewrite history to
  drop those files, or start the public `main` from a single import commit of
  `v2.2.13` with those files removed, recording the upstream commit hash.
- **Hosting** of the repository and the COPR.
