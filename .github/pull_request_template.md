## What this changes

<!-- One feature or one fix per pull request. Small, focused pull requests are reviewed faster. -->

## Why

<!-- The problem it solves, or the issue/discussion it comes from (e.g. "Fixes #12"). -->

## How I tested it

<!-- What you ran or tried. Screenshots for anything visible; a benchmark for any performance claim. -->

## Checklist

- [ ] Each commit subject starts with a label: `[general]`, `[fedora]`, `[brand]`, `[fork]`, `[ci]` or `[bench]` (see FORK.md)
- [ ] `python3 -I tools/asset-inventory --strict` and `python3 -I tools/lint-baseline --check` pass
- [ ] New fonts, icons, sounds or images have a source and a redistributable licence
- [ ] If upstream Serpantinum files changed: ran `bash tools/changes-from-upstream` in the same commit
