# Translation tools

Scripts that keep the translation files in `quickshell/ii/translations/` in sync with the
strings in the QML source. They extract translatable text, fill in missing keys, and drop keys
that no code uses anymore.

Three pieces:

| File | Job |
|------|-----|
| `manage-translations.sh` | Wrapper. The interface you normally use. |
| `translation-manager.py` | Extracts strings and adds/removes keys per language. |
| `translation-cleaner.py` | Removes unused keys and aligns key structure across languages. |

The wrapper finds its own paths, so you can run it from anywhere.

## Quick start

```bash
cd quickshell/ii/translations/tools

./manage-translations.sh status          # how many strings, how many keys per language
./manage-translations.sh extract         # pull translatable strings from the QML
./manage-translations.sh update          # add missing / remove stale keys, all languages
./manage-translations.sh update -l zh_CN # one language
./manage-translations.sh clean           # delete keys no code references
./manage-translations.sh sync            # match every language's key set to en_US
```

Add `-y` to skip the confirmation prompts (useful in scripts).

## Common workflows

**After changing UI strings**

```bash
./manage-translations.sh status   # see what drifted
./manage-translations.sh update   # apply
./manage-translations.sh clean    # optional: drop now-unused keys
```

**Add a language**

```bash
./manage-translations.sh update -l de_DE   # creates de_DE.json with the current keys
./manage-translations.sh sync              # align its structure to en_US
```

**After a large refactor**

```bash
cp -r quickshell/ii/translations quickshell/ii/translations.backup
./manage-translations.sh clean
./manage-translations.sh sync
```

## Running the Python scripts directly

The wrapper covers the usual cases. Call the scripts yourself when you need flags it doesn't expose.

`translation-manager.py` extracts and updates:

```bash
./translation-manager.py                       # all languages
./translation-manager.py -l zh_CN              # one language
./translation-manager.py -e                    # extract only, no writes
./translation-manager.py -e --show-temp        # extract and print what was found
```

| Flag | Meaning |
|------|---------|
| `-t`, `--translations-dir` | Translation files (default points at the repo layout; pass it if you run from elsewhere) |
| `-s`, `--source-dir` | QML source to scan (default `.config/quickshell/ii`) |
| `-l`, `--language` | One language code instead of all |
| `-e`, `--extract-only` | Extract without writing files |
| `--show-temp` | Print the extracted strings |

`translation-cleaner.py` prunes and aligns:

```bash
./translation-cleaner.py --clean                  # remove unused keys
./translation-cleaner.py --sync                   # align keys to en_US
./translation-cleaner.py --sync --source-lang zh_CN  # align to a different base
./translation-cleaner.py --clean --no-backup      # skip the automatic backup
```

## What gets extracted

The extractor looks for `Translation.tr(...)` calls:

```qml
Translation.tr("Hello, world!")
Translation.tr('Hello, world!')
Translation.tr(`Hello, world!`)
Translation.tr("Line 1\nLine 2")
Translation.tr("Say \"Hello\"")
Translation.tr("Hello, %1!").arg(name)
```

It reads literal strings only. A string built at runtime (concatenation, a variable) won't be
found, so add those keys by hand and mark them keep (below).

## Keeping a key the cleaner can't see

Append `/*keep*/` to a value and `clean`/`sync` will leave it alone. Use this for keys whose source
strings are dynamic:

```json
{
  "dynamic_key": "Some dynamic value /*keep*/"
}
```

## Notes

- The cleaner backs up before deleting, but back up important files yourself too.
- Every translation file is UTF-8.
- Key names should be English, no special characters.

## Troubleshooting

**Text doesn't show after I added `Translation.tr`.** The QML file needs `import "root:/"`.

**The extracted count looks wrong.** A string is probably built at runtime instead of passed as a
literal to `tr()`. Extraction only sees literals.

**`sync` dropped translations.** The base language was missing those keys. Check `en_US.json`, or
sync from a more complete language with `--source-lang`.

**`clean` removed a key I needed.** Restore from the backup and mark the key `/*keep*/` if its
source string is dynamic.

```bash
# restore one file
cp quickshell/ii/translations/zh_CN.json.backup quickshell/ii/translations/zh_CN.json
# restore all
cp quickshell/ii/translations.backup/* quickshell/ii/translations/
```
