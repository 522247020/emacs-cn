# Changelog

All notable changes to the Chinese localization are documented here.
版本号见仓库根目录的 `VERSION`（发新版本时递增并推送到 `main`，CI 会自动打 tag 并发 Release）。

## 31.1.50-cn2

### 界面

- 完整翻译 **docstring**（`C-h f` / `C-h v` / `C-h k` / `C-h m`），同时处理
  help 缓冲区使用的 raw 形式。
- 修复 `easy-menu-define` 动态菜单（Info 等主模式菜单此前仍是英文）。
- 按键信息保护：单字母按键（`m`/`u`/`o`/`R`…）不再被误译；`@:`/`e.g.`
  等转义与缩写保持原样。
- 词表扩充至约 6.5 万条（含完整 docstring）。

### 手册

- 机器翻译官方 Texinfo 手册并接入 Info：
  - Emacs 手册 `(emacs)`
  - Emacs Lisp 参考手册 `(elisp)`
  - Emacs Lisp 入门 `(eintr)`
  - `doc/misc` 下全部 68 本（FAQ、Gnus、Tramp、Calc、CC Mode、CL、Eshell、
    Erc、RefTeX、Viper、Widget、Use-package、Eglot、Flymake、Woman、
    Autotype、DBus、Todo、MH-E、Modus Themes、Org 等）
- 翻译器 `l10n/texi-translate.py`：保留 Texinfo 标记，跳过 `@example`/`@macro`
  等块，节点名保持英文。

## 31.1.50-cn6

### 打包 / 平台

- 新增 **apt 仓库**（托管于 GitHub Pages）：Debian/Ubuntu 可直接
  `apt install emacs-cn` / `emacs-cn-wayland` 并获得更新。生成脚本
  `ci/make-apt-repo.sh`（多架构 Packages/Release，可选 GPG 签名）。

## 31.1.50-cn5

### 打包 / 平台

- **修复树莓派（Raspberry Pi OS）安装失败**：此前 `.deb` 在 Ubuntu 上构建，
  依赖 `libjpeg-turbo8`（`libjpeg.so.8`），与 Debian 系的 `libjpeg62-turbo`
  （`libjpeg.so.62`）SONAME 不兼容。现改为在 **Debian 容器**里构建
  `emacs-cn-debian_*.deb`；Ubuntu 仍单独产出 `emacs-cn-ubuntu_*.deb`。
- `.deb` 依赖改为用 `ldd` + `dpkg -S` 从实际二进制推导（在哪个发行版构建，
  就得到该发行版的正确包名），并保留兼容 Debian/Ubuntu 的兜底列表。
- `.deb` 文件名加入发行版标识；`libgccjit` 改为可选 `Recommends`。

## 31.1.50-cn4

### 打包 / 平台

- GitHub 工作流新增 **Arch (pacman)** 构建（`build-arch`），使 GitHub 的
  Release 同时提供 `.deb` 与 `.pkg.tar.zst`（此前 GitHub 只有 Debian 产物）。
- GitHub 覆盖：Debian 的 amd64/arm64 × X11/Wayland，Arch 的 x86_64 × X11/Wayland。

## 31.1.50-cn3

### 打包 / 平台

- 产出**发行版原生包**：Debian/Ubuntu 的 `.deb`、Arch 的 pacman 包
  （`ci/make-package.sh`），与便携 `tar.zst` 一并上传到 Release。
- 支持 **arm64/aarch64**：产物按架构命名，GitHub Actions 用 ARM runner 构建。
- 新增 **Wayland 原生版**（`--with-pgtk`，包名 `emacs-cn-wayland`，对应
  Arch 的 `emacs-wayland`）；用 `TOOLKIT=pgtk` 切换，两变体互相冲突。
- CI 覆盖 **x86_64 + arm64 × X11 + Wayland** 四种组合。

## 31.1.50-cn2

### 工程

- 依赖安装脚本同时支持 **Arch** 与 **Debian/Ubuntu**（`ci/install-deps.sh`）。
- 预编译产物按发行版区分：`emacs-cn-{arch,debian}-x86_64.tar.zst`
  （动态链接的 soname 差异，例如 Arch 的 `libxml2.so.16` 与 Ubuntu 的 `.so.2`）。
- `install.sh`：自动识别安装前缀、补齐缺失运行库、创建 `emacs-cn` 命令与桌面项。
- CI：GitHub Actions 与 Gitea Actions（Gitea 版不依赖外部 action）。
- 更新工具：`ci/apply-l10n.sh`、`ci/apply-manual-zh.sh`、`ci/update-emacs.sh`。

## 31.1.50-cn1

- 首个中文版本：消息、错误、提示、菜单栏/工具栏、启动画面、模式名、
  Customize 部件、是/否询问等界面汉化。
- C 层挂钩（`message3`/`vmessage`/`Fformat_message`/`print_error_message`）
  与 Lisp 框架 `chinese-l10n.el`。
