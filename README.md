# Chinese Localized GNU Emacs (Emacs 中文版)

A Chinese-localized build of **GNU Emacs 31.1**, where the visible user
interface, documentation strings, menus, prompts and even the Texinfo
manuals are translated into Simplified Chinese.  Command names, function
names, key sequences and Lisp symbols are kept as-is on purpose so that
everything keeps working.

> 中文说明见 [README.zh-CN.md](README.zh-CN.md)。

## Screenshot

Terminal capture (see `docs/screenshot-tty.txt`):

```
欢迎使用 GNU Emacs，它是 GNU/Linux 操作系统的一个组件。

获取帮助	   C-h  （按住 CTRL 并按下 h）
Emacs 手册	   C-h r	浏览手册	   C-h i
Emacs 教程	   C-h t	撤销更改	   C-x u
购买手册	   C-h RET	退出 Emacs	   C-x C-c
激活菜单栏   M-`

实用任务：
访问新文件			打开主目录
自定义启动		打开 *scratch* 缓冲区

菜单栏：  帮助 文件 编辑 选项 缓冲区 工具

回显消息：  缓冲区开头 / 已设置标记 / 正在保存文件x.el... / 退出
```

## What is translated

| Surface | Example |
| --- | --- |
| Echo-area messages, errors, warnings | `Beginning of buffer → 缓冲区开头` |
| Minibuffer prompts | `Find file → 查找文件` |
| Menu bar / tool bar / pop-up menus | `文件`、`编辑`、`打开文件…` |
| `M-x` completion annotations (marginalia) | docstring first line |
| Key pop-up (`which-key`) descriptions | `Find file → 查找文件`, `prefix → 前缀` |
| `tabulated-list` headers | `Package → 软件包` |
| Full docstrings for `C-h f` / `C-h v` / `C-h k` / `C-h m` | |
| Startup screen, mode names, Customize widgets, yes/no prompts | |

### Translated manuals (`C-h r` / `C-h i`)

| Manual | Info name |
| --- | --- |
| Emacs Manual | `(emacs)` |
| Emacs Lisp Reference Manual | `(elisp)` |
| Emacs Lisp Intro | `(eintr)` |
| Org Manual | `(org)` |
| …and the manuals under `doc/misc` | |

The manuals are machine translated with a Texinfo-aware pipeline that
preserves all markup and keeps node names in English so cross-references
keep working.

## Download and install

The CI publishes, for each release, native packages and portable tarballs,
for **x86_64 and arm64**, and for two graphics backends:

* **X11** (default): `--with-x-toolkit=gtk3` — package name `emacs-cn`.
* **Wayland (pgtk)**: `--with-pgtk` (pure GTK, native Wayland) — package name
  `emacs-cn-wayland`, equivalent to Arch's `emacs-wayland`.

Because Emacs is dynamically linked, the `.deb` is built separately on
**Debian** and **Ubuntu** (their library names *and SONAMEs* differ, e.g.
Debian's `libjpeg62-turbo`/`libjpeg.so.62` vs Ubuntu's
`libjpeg-turbo8`/`libjpeg.so.8`).

| File pattern | For |
| --- | --- |
| `emacs-cn-debian_*_<arch>.deb` | Debian, Raspberry Pi OS … (X11) |
| `emacs-cn-wayland-debian_*_<arch>.deb` | Debian, Raspberry Pi OS … (Wayland) |
| `emacs-cn-ubuntu_*_<arch>.deb` | Ubuntu (X11) |
| `emacs-cn-wayland-ubuntu_*_<arch>.deb` | Ubuntu (Wayland) |
| `emacs-cn-*-<arch>.pkg.tar.zst` | Arch/Manjaro, X11 |
| `emacs-cn-wayland-*-<arch>.pkg.tar.zst` | Arch/Manjaro, Wayland |
| `emacs-cn-<distro>-<arch>[-pgtk].tar.zst` | portable tarball |

`<arch>` is `amd64`/`arm64` for `.deb`, `x86_64`/`aarch64` for pacman and
tarballs.

```sh
# Debian / Raspberry Pi OS
sudo apt install ./emacs-cn-debian_*_arm64.deb
sudo apt install ./emacs-cn-wayland-debian_*_arm64.deb   # Wayland

# Ubuntu
sudo apt install ./emacs-cn-ubuntu_*_amd64.deb

# Arch / Manjaro / Omarchy
sudo pacman -U emacs-cn-*-x86_64.pkg.tar.zst
sudo pacman -U emacs-cn-wayland-*-x86_64.pkg.tar.zst      # Wayland

# portable tarball (the prefix is compiled in, so extract to /)
sudo tar --zstd -xf emacs-cn-<distro>-<arch>[-pgtk].tar.zst -C /

emacs-cn -nw
```

> The X11 and Wayland variants both install to `/opt/emacs-cn` and declare a
> conflict with each other — install only one.  Likewise pick the `.deb`
> built for your distribution and CPU (an `amd64` package cannot be installed
> on `arm64`).

### apt repository

The CI also publishes an apt repository on GitHub Pages, so you can use
`apt install` and receive updates:

```sh
# Debian / Raspberry Pi OS
echo "deb [trusted=yes] https://522247020.github.io/emacs-cn/debian stable main" \
  | sudo tee /etc/apt/sources.list.d/emacs-cn.list

# Ubuntu: use .../emacs-cn/ubuntu instead (libraries differ)
sudo apt update
sudo apt install emacs-cn            # X11
sudo apt install emacs-cn-wayland    # Wayland (pgtk)
```

Enable it once in **Settings → Pages → Source: GitHub Actions**.  On a
**private** repository GitHub Pages needs a paid plan — in that case use the
`.deb` from Releases or build locally.  Signing is supported by exporting the
private key to the `APT_GPG_KEY` secret (otherwise `[trusted=yes]` is used).

## Build from source

```sh
git clone https://github.com/<you>/emacs-cn.git
cd emacs-cn

sh ci/install-deps.sh                 # Arch (pacman) or Debian/Ubuntu (apt)
PREFIX=$HOME/.local/emacs-cn sh ci/build-emacs.sh
```

`ci/build-emacs.sh` applies the Chinese UI data, the translated manuals, and
falls back to a non-native-compiled build if `libgccjit` is missing.

## Repository layout

```
emacs-cn/
├── src/                     # GNU Emacs 31.1 source with the localization applied
│   └── lisp/international/
│       ├── chinese-l10n.el        # runtime localization framework
│       └── chinese-l10n-data.el   # ~65k UI strings / docstrings
├── l10n/                    # extraction / translation / data generation
│   ├── texi-translate.py        # Texinfo manual translator
│   └── manual-zh/               # translated manuals (*.texi)
├── ci/
│   ├── install-deps.sh          # build deps for Arch / Debian / Ubuntu
│   ├── build-emacs.sh           # configure + build + package
│   ├── apply-l10n.sh            # apply code localization
│   ├── apply-manual-zh.sh       # apply translated manuals
│   └── update-emacs.sh          # upgrade to a new upstream ref
├── .github/workflows/build.yml  # GitHub Actions
├── .gitea/workflows/build.yml   # Gitea Actions (action-free)
├── install.sh                   # install a prebuilt tarball
└── README.zh-CN.md
```

## How it works

* **C hooks** — `message3` / `vmessage` / `Fformat_message` /
  `print_error_message` consult the `chinese-l10n-table` hash table, so
  messages, errors and `format-message` output are translated.
* **Lisp framework** (`chinese-l10n.el`) — prompts, keymaps, `easy-menu`
  menus, which-key, marginalia, `widget` tags, mode names, and the
  `documentation` / `documentation-property` output.
* **Translation pipeline** (`l10n/`) — extracts UI strings and manuals,
  translates them via an online engine with placeholder protection, and
  generates `chinese-l10n-data.el` and the translated `.texi`.

## Update Emacs

```sh
sh ci/update-emacs.sh emacs-31   # fetch upstream, re-apply the localization
```

## License

* The GNU Emacs source is distributed under the GNU General Public License,
  version 3 or later (see `src/COPYING`).
* The translated manuals derive from the Emacs manuals, which are under the
  GNU Free Documentation License 1.3 or later (see `src/doc/*/doclicense.texi`).
* The localization tooling and translation data in this repository are
  released under the same terms as Emacs.

## Contributing

Corrections to the translation are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md)
and [docs/translation.md](docs/translation.md).  Version history is in
[CHANGELOG.md](CHANGELOG.md).
