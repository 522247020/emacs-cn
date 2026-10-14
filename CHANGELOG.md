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

### 工程

- 产出**发行版原生包**：Debian/Ubuntu 的 `.deb`、Arch 的 pacman 包
  （`ci/make-package.sh`），CI 与便携 `tar.zst` 一并上传到 Release。
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
