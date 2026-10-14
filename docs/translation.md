# Translation pipeline / 翻译流水线

This document explains how the Chinese localization is produced and how to
regenerate or extend it.

## Overview

```
            UI strings                              Texinfo manuals
   ┌──────────────────────────┐            ┌──────────────────────────┐
   │ l10n/extract.py          │            │ l10n/texi-translate.py   │
   │  (Lisp/C source +        │            │  (doc/*/*.texi)          │
   │   runtime docstrings)    │            │                          │
   └────────────┬─────────────┘            └────────────┬─────────────┘
                ▼                                       ▼
   ┌──────────────────────────┐            ┌──────────────────────────┐
   │ l10n/translate.py        │            │ Google translate (batch) │
   │  placeholders + cache    │            │  + manual-cache.jsonl    │
   └────────────┬─────────────┘            └────────────┬─────────────┘
                ▼                                       ▼
   ┌──────────────────────────┐            ┌──────────────────────────┐
   │ l10n/make-data.py        │            │ l10n/manual-zh/<man>/    │
   │  → chinese-l10n-data.el  │            │  ci/apply-manual-zh.sh   │
   └────────────┬─────────────┘            └────────────┬─────────────┘
                ▼                                       ▼
        runtime hash table                      src/doc/<man>/*.texi
        (C hooks + Lisp)                        → makeinfo → .info
```

## 1. UI strings

1. **Extract** — `python3 l10n/extract.py`
   * scans `src/lisp/**/*.el` and `src/src/*.c` for user-visible strings
     (`message`/`error`/`warn`, prompts, menu items, `:tag`/`:help`,
     `define-error`, `PUT_ERROR`, …);
   * also reads `l10n/docstrings.txt` / `docstrings-raw.txt` (full
     docstrings dumped from a running Emacs) and `l10n/doom-desc.txt`.
   * writes `l10n/strings.jsonl`.

2. **Translate** — `python3 l10n/translate.py`
   * batches strings to an online engine;
   * **protects** `%s` placeholders (rewritten to `%1$s`), `` `symbol' ``,
     key sequences, single-letter keys, `e.g.`/`i.e.`, and layout characters;
   * validates that the format specifiers survive;
   * caches results in `l10n/cache.jsonl` (resumable).

3. **Generate** — `python3 l10n/make-data.py`
   * merges the cache, applies the hand-written `MANUAL` overrides and the
     `POST_FIX` normalisations;
   * writes `src/lisp/international/chinese-l10n-data.el`.

The runtime then loads this table and the C hooks / Lisp framework
(`chinese-l10n.el`) use it.  See the main README for details.

## 2. Manuals

`l10n/texi-translate.py` is **Texinfo aware**:

* translates body **paragraphs**, section titles, menu descriptions and
  `@item` labels;
* leaves all markup untouched — `@code{}`, `@xref{}`, `@node`, `@cindex`,
  `@macro` bodies, `@example` blocks, etc. are passed through by a
  placeholder mechanism;
* keeps **node names in English** so cross references keep working;
* translates whole paragraphs (re-joining wrapped lines) for better quality;
* caches results in `l10n/manual-cache.jsonl`.

Usage:

```sh
# whole manual directory
python3 l10n/texi-translate.py --src src/doc/lispref --out l10n/manual-zh/lispref

# only specific files (plus their @include dependencies)
python3 l10n/texi-translate.py --src src/doc/misc --out l10n/manual-zh/misc \
    --only org.texi,doclicense.texi
```

`ci/apply-manual-zh.sh` copies `l10n/manual-zh/<dir>/*.texi` into
`src/doc/<dir>/`; `ci/build-emacs.sh` calls it before building, so
`make install` produces Chinese `.info` files and `C-h r` / `C-h i` open
them.

## 3. Protecting translations

Two rules matter most:

* **Format parameters** — `Search failed: %s` becomes `%1$s` in the
  translation, so reordering clauses never swaps arguments.
* **Keys and symbols** — a lone `m`, `u`, `o`, `R` … is a keybinding, not a
  word; `@:`, `e.g.`, `` `foo' `` and `\[command]` are never translated.

## 4. Overriding machine translations

Machine translation is not perfect.  Put corrections in the `MANUAL` dict
of `l10n/make-data.py` — they always win:

```python
MANUAL = {
    'Open *scratch* buffer': '打开 *scratch* 缓冲区',
}
```

Then `python3 l10n/make-data.py` and rebuild.

## 5. Adding a manual

```sh
python3 l10n/texi-translate.py --src src/doc/<dir> --out l10n/manual-zh/<dir>
git add l10n/manual-zh/<dir>
```

`make info` must succeed for the new manual.
