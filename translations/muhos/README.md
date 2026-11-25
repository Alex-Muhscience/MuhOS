# Translating MuhOS

MuhOS's own wording (menus, the control centre, search, the lock screen and
so on) is in `en.json`, generated from the code by `tools/muhos-strings`.
Everything else comes from Serpantinum's language files in
`src/assets/languages/`, which are translated upstream.

To translate:

1. Copy `en.json` to `<lang>.json`, using the language's file name from
   `src/assets/languages/` (for example `de.json`, `pt.json`, `zh_tw.json`).
2. Translate the values. Keep the keys, and keep `%1` and `{author}` where
   they are: they are filled in with names.
3. Leave out anything you don't want to translate yet; it stays in English.
4. Check it: `python3 tools/muhos-strings --check`.
5. Open a pull request.

The package build merges these files into the shell's language files
(`tools/brand-languages`), so Serpantinum's own files are never edited.
