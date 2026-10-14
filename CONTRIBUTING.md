# Contributing to emacs-cn / 参与贡献

Thanks for helping improve the Chinese localization of GNU Emacs!
感谢你帮助完善 GNU Emacs 的汉化！

Everything here is data-driven: the localization is a table of
English → Chinese strings plus translated Texinfo manuals, so most
contributions are simple text edits.

---

## 1. Report an untranslated or wrong string

Open an issue with:

* the exact English text (or a screenshot),
* where it appears (menu, message, `C-h f`, a manual node, …),
* your suggested Chinese.

中文也可以，直接贴出英文原文、出现位置和建议译文即可。

## 2. Fix a UI string

There are two kinds of UI text:

| Kind | Where | How to change |
| --- | --- | --- |
| Arbitrary messages / prompts / menus / docstrings | the generated table | add an override (below) |
| Fixed strings patched into the C/Lisp source | `patches/emacs-cn.patch` + `src/` | edit the source, see §4 |

The quickest fix is an **override** in `l10n/make-data.py` (the `MANUAL`
dict), which always wins over machine translation:

```python
MANUAL = {
    ...
    'Open *scratch* buffer': '打开 *scratch* 缓冲区',
}
```

Then regenerate the table and rebuild:

```sh
python3 l10n/make-data.py
cd src && rm -f src/emacs.pdmp && make -j"$(nproc)"
```

## 3. Fix a manual translation

The manuals are Texinfo files under `l10n/manual-zh/<manual>/`.
Edit the relevant `.texi` directly, keeping all `@` markup and the
**English node names** intact.  Verify it still builds:

```sh
cd src/doc/<manual> && make info
```

To re-translate a whole manual from scratch instead:

```sh
python3 l10n/texi-translate.py --src src/doc/lispref --out l10n/manual-zh/lispref
```

## 4. Change the localized source (C / Lisp)

The shipped source in `src/` already contains the localization.  Keep the
patch in sync so future upstream updates can re-apply it:

```sh
# edit src/... as needed, then regenerate patches/emacs-cn.patch
# (needs a pristine upstream tree in /tmp/emacs-base)
git ls-files src/ | while IFS= read -r f; do
  rel=${f#src/}
  [ "$rel" = lisp/international/chinese-l10n-data.el ] && continue
  base=/tmp/emacs-base/$rel
  if [ -f "$base" ]; then cmp -s "$base" "$f" || diff -u --label "a/$rel" --label "b/$rel" "$base" "$f"
  else diff -u --label /dev/null --label "b/$rel" /dev/null "$f"; fi
done > patches/emacs-cn.patch
```

## 5. Add a new manual

```sh
python3 l10n/texi-translate.py --src src/doc/<dir> --out l10n/manual-zh/<dir>
git add l10n/manual-zh/<dir>
```

`ci/apply-manual-zh.sh` picks it up automatically (it iterates the
sub-directories of `l10n/manual-zh/`).

## 6. Build & test

```sh
sh ci/install-deps.sh                 # Arch or Debian/Ubuntu
PREFIX=$HOME/.local/emacs-cn sh ci/build-emacs.sh
$HOME/.local/emacs-cn/bin/emacs -nw
```

## Guidelines

* **Do not translate** command names, function/variable names, Lisp
  symbols, or key sequences (`C-x C-f`, `M-x`, `RET`).
* Keep `%s` / `%d` etc. in messages; use positional `%1$s` only if you
  must reorder arguments.
* In `.texi`, never translate `@node` names or the arguments of
  `@code`/`@kbd`/`@key`/`@var`/`@xref`.
* Keep the build green: `make info` must succeed.
* Prefer small, focused pull requests.

## License

By contributing you agree that your changes are licensed under the same
terms as the rest of the project (GPL-3.0-or-later for Emacs itself,
GFDL-1.3-or-later for the manuals).
