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

- `origin`: `https://github.com/Alex-Muhscience/MuhOS` (private for now).
- `upstream`: `https://github.com/ilyamiro/serpantinum.git`, fetch only
  (push disabled). Its history and tags are **never pushed** to `origin`:
  upstream history contains fonts that may not be redistributed.
- `upstream-snapshots`: one commit per upstream release, each a snapshot of
  that release without the files in `tools/upstream-exclude.txt`, tagged
  `muhos-upstream-v<version>`. The first snapshot is the root of MuhOS history.
- `main`: MuhOS. Merges snapshots; never merges upstream commits directly.
- Current base: upstream v2.2.13 (`d6f1c8d`), snapshot `muhos-upstream-v2.2.13`.

### Syncing to a new upstream release

```sh
git fetch upstream --tags
git switch -c sync/vX.Y.Z main
tools/sync-upstream vX.Y.Z       # snapshot + tag + merge; credits upstream authors
# resolve conflicts if any, then set "Based on" in NOTICE to vX.Y.Z
tools/asset-inventory --check    # new upstream assets must be classified
tools/changes-from-upstream
```

`README.md` is MuhOS's own; when an upstream sync conflicts on it, keep the
MuhOS version and carry over any upstream fact worth keeping by hand.

Run the lint, package and benchmark checks, then merge `sync/vX.Y.Z` into
`main`. Push `main`, `upstream-snapshots` and the new `muhos-upstream-*` tag
by name; never `git push --tags`.

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

Upstream files carry no license headers, and per-file "modified by" comments
would have to be stripped from every `[general]` patch offered upstream.
Instead, `tools/changes-from-upstream` lists every upstream file MuhOS changed
or removed, with the date of the first change, in `CHANGES-FROM-UPSTREAM.md`.
That generated list is the AGPL section 5(a) notice; `NOTICE` points to it.
Regenerate it in the same commit that touches upstream files.

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

## Decisions

- **History** (2026-10-18): MuhOS history starts from a clean import commit
  of v2.2.13 without the excluded fonts; upstream history is not published.
- **Hosting** (2026-10-18): GitHub (`Alex-Muhscience/MuhOS`, private for now)
  with source RPMs attached to releases; Fedora COPR later.
- **Dependencies** (2026-10-18): MuhOS packages Quickshell and Matugen itself;
  Hyprland comes from a third-party COPR for now.
- **Assets** (2026-10-18): trace the source and license of every bundled
  asset; anything that cannot be cleared is replaced with openly licensed
  material.
