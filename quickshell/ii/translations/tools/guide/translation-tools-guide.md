# Translation tools guide

A longer walkthrough of the translation scripts in `quickshell/ii/translations/tools/`. For the
short reference, see [the README](../README.md). This guide adds example output and step-by-step
workflows.

The tools keep the files in `quickshell/ii/translations/` in sync with the `Translation.tr(...)`
strings in the QML source: they extract strings, add missing keys, and remove keys no code uses.

## The three scripts

- `manage-translations.sh`: wrapper with one command per task. The interface you normally use.
- `translation-manager.py`: extracts strings, adds and removes keys per language.
- `translation-cleaner.py`: removes unused keys and aligns key structure across languages.

The wrapper resolves its own paths, so it runs from any directory.

## Quick start

```bash
cd quickshell/ii/translations/tools

./manage-translations.sh --help
./manage-translations.sh status            # string count and per-language key counts
./manage-translations.sh extract           # pull strings from the QML
./manage-translations.sh update            # add missing / remove stale keys, all languages
./manage-translations.sh update -l zh_CN   # one language
./manage-translations.sh clean             # drop keys no code references
./manage-translations.sh sync              # match every language to en_US
```

Add `-y` to skip confirmation prompts.

You can also call it by full path from the repo root:

```bash
quickshell/ii/translations/tools/manage-translations.sh status
quickshell/ii/translations/tools/manage-translations.sh update
```

## Running the scripts directly

`translation-manager.py` extracts and updates:

```bash
./translation-manager.py                  # all languages
./translation-manager.py -l zh_CN         # one language
./translation-manager.py -e               # extract only, no writes
./translation-manager.py -e --show-temp   # extract and print the strings found
```

| Flag | Meaning |
|------|---------|
| `-t`, `--translations-dir` | Translation files directory (pass it when running from outside the repo) |
| `-s`, `--source-dir` | QML source to scan (default `.config/quickshell/ii`) |
| `-l`, `--language` | One language code instead of all |
| `-e`, `--extract-only` | Extract without writing |
| `--show-temp` | Print the extracted strings |

`translation-cleaner.py` prunes and aligns:

```bash
./translation-cleaner.py --clean                     # remove unused keys
./translation-cleaner.py --sync                      # align keys to en_US
./translation-cleaner.py --sync --source-lang zh_CN  # align to a different base
./translation-cleaner.py --clean --no-backup         # skip the automatic backup
```

## Workflows

**Routine update after changing strings**

```bash
./manage-translations.sh status   # see what drifted
./manage-translations.sh update   # apply
./manage-translations.sh clean    # optional: remove now-unused keys
```

**Add a language**

```bash
./manage-translations.sh update -l de_DE   # create de_DE.json with current keys
./manage-translations.sh sync              # align its structure to en_US
```

**Cleanup after a large refactor**

```bash
cp -r quickshell/ii/translations quickshell/ii/translations.backup
./manage-translations.sh clean
./manage-translations.sh sync
```

## What gets extracted

The extractor matches `Translation.tr(...)` calls with literal strings:

```qml
Translation.tr("Hello, world!")
Translation.tr('Hello, world!')
Translation.tr(`Hello, world!`)
Translation.tr("Line 1\nLine 2")
Translation.tr("Say \"Hello\"")
Translation.tr("Hello, %1!").arg(name)
```

A string built at runtime (concatenation or a variable) won't match. Add those keys by hand and
mark them keep (see below).

## Example output

**Status**

```
$ ./manage-translations.sh status
Analyzing translation status...
=== Current Project Status ===
166 translatable texts extracted

=== Translation File Status ===
  en_US: 470 keys
  zh_CN: 470 keys
```

**Update one language**

```
$ ./manage-translations.sh update -l zh_CN
Processing language: zh_CN
Analysis result:
  Missing keys: 5
  Extra keys: 20

Found 5 missing translation keys:
1. "New feature text"
2. "Another new text"
...
Add these 5 missing keys? (y/n): y
5 keys added

Found 20 extra translation keys:
1. "Removed old text" -> "已删除的旧文本"
...
Delete these 20 extra keys? (y/n): y
20 keys deleted

Translation file saved
```

**Clean unused keys**

```
$ ./manage-translations.sh clean
Processing language: zh_CN
Found 50 unused keys:
  1. "old_unused_text"
  2. "deprecated_message"
  ...
Delete these 50 unused keys? (y/n): y
50 keys deleted
Original key count: 470, after cleaning: 420
```

## Keeping a key the cleaner can't see

Append `/*keep*/` to a value. `clean` and `sync` skip those keys. Use it for keys whose source
strings are dynamic:

```json
{
  "dynamic_key": "Some dynamic value /*keep*/"
}
```

## Custom directories

Point the scripts at a different layout with `-t` and `-s`:

```bash
./translation-manager.py \
  --translations-dir /path/to/translations \
  --source-dir /path/to/source
```

## Notes

- The cleaner backs up before deleting. Back up important files yourself too.
- Every translation file is UTF-8.
- Key names should be English, no special characters.

## Troubleshooting

**Text doesn't show after adding `Translation.tr`.** The QML file needs `import "root:/"`.

**The extracted count looks off.** A string is probably built at runtime instead of passed as a
literal. Extraction only sees literals.

**`sync` dropped translations.** The base language was missing those keys. Check `en_US.json`, or
sync from a more complete language with `--source-lang`.

**`clean` removed a key you needed.** Restore from the backup, then mark the key `/*keep*/` if its
source string is dynamic.

```bash
# restore one file
cp quickshell/ii/translations/zh_CN.json.backup quickshell/ii/translations/zh_CN.json
# restore all
cp quickshell/ii/translations.backup/* quickshell/ii/translations/
```
