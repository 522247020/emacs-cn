# GNU Emacs 中文汉化版

本仓库制作了**简体中文界面版 Emacs**。除命令名、函数名、变量名和按键序列外，
尽可能把用户可见的界面信息翻译为中文。提供两个版本：

| 版本 | 源码 | 安装 | 适用 |
| --- | --- | --- | --- |
| **31.1.50**（推荐） | `src31/` | `install31/` | **Doom Emacs 用户**（与 Doom 的 `init.31.1.el` / `straight/build-31.1` 匹配） |
| 30.2.50 | `src/` | `install/` | 独立使用、非 Doom 场景 |

- 源码分别基于 `emacs-31`、`emacs-30` 分支
- 汉化工具与词表：`l10n/`
- 翻译词条：**约 65,800 条**（`*/lisp/international/chinese-l10n-data.el`，约 25MB）
- 其中包含约 **22,800 条完整 docstring** + **13,000 条 raw docstring**，
  供 `C-h f` / `C-h v` / `C-h k` / `C-h m` 显示中文

## 与 Doom Emacs 的兼容性（重要）

Doom 的生成状态是**按 Emacs 主/次版本区分**的：

```
~/.config/emacs/.local/etc/@/init.31.1.el      # profile 初始化文件
~/.config/emacs/.local/straight/build-31.1/    # 包编译产物
~/.config/emacs/eln-cache/31.1-<hash>/         # 原生编译缓存
```

如果用一个**不同版本**的 Emacs（例如 30.2.50）加载这套 Doom 配置，会因找不到
`init.<版本>.el` 而报：

```
Doom hasn't been initialized yet; did you remember to run 'doom sync' in the shell?
Error (doom-after-init-hook): ... (void-variable doom-modules)
```

这**不是汉化引起的**，而是 Emacs 版本不匹配。解决办法就是使用与本机 Doom 同版本的
汉化构建——即上面的 **31.1.50** 版（`install31/`）。已实测该版本可正常加载：

```
Doom loaded 143 packages across 37 modules
```

如果你改用 30.2.50 版加载 Doom，则需要用该 Emacs 重新执行 `doom sync`
（会为 30.2 另建一套 `init.30.2.el` 与 `build-30.2.50`）。

## 关于 `M-x` 与按键弹窗

- **`M-x` 补全列表**：命令名本身（如 `find-file`）按你的要求保持英文；右侧
  的注解由 marginalia 提供，其中命令的 docstring 首行已汉化（共提取约 6000 条）。
- **按键弹窗（which-key）**：
  - 有自定义描述的命令/分组（Doom 的 `:desc`/`:prefix`，约 680 条）→ 显示其中文描述；
  - 没有自定义描述的命令（典型如内置的 `C-x` 前缀）→ 改为显示其中文
    **docstring 首行**，而不再是英文命令名；
  - 子键位图：常用 `C-x` 子前缀已给中文名（`C-x r`→寄存器/矩形/书签、
    `C-x t`→标签页、`C-x n`→缩窄、`C-x x`→缓冲区……）；未收录的仍显示 `+前缀`。

这两处通过 `chinese-l10n.el` 中的 advice 实现，仅对描述文本做词表替换，
不影响命令查找与执行。若想改回 which-key 显命令名，可设置：

```elisp
(advice-remove 'which-key--maybe-add-docstring
               #'chinese-l10n--wk-maybe-add-docstring)
```

## 完整 docstring 翻译

`chinese-l10n.el` 会拦截 `documentation` 与 `documentation-property`，
把返回值换成词典中的中文 docstring。`:filter-return` 处理了 help 缓冲区
使用的 **raw** docstring：先直接查表，未命中时先做 `substitute-command-keys`
再查表，因此 `C-h f`（raw）与 which-key/marginalia（非 raw）都能命中。

> 注意：词表包含完整 docstring，dump 体积会增至约 39MB；这是正常的。

## 已汉化的内容

| 界面元素 | 说明 |
| --- | --- |
| 回显区消息 / `message` | 如 “正在保存文件…”、“缓冲区开头” |
| 错误与警告信息 | `error`、`user-error`、`warn`、以及 C 层错误符号 |
| 迷你缓冲区提示 | `find-file`、`kill-buffer` 等所有 `read-*` / `completing-read` 提示 |
| 菜单栏 / 工具栏 / 弹出菜单 | 菜单项标签与 `:help` 工具提示 |
| 启动画面 / 关于画面 | 图形版与终端版 |
| 模式行模式名 | 如 `Fundamental → 基本`、`Compilation → 编译` |
| Customize 等部件按钮 | `:tag` 标签，如 `Apply → 应用` |
| 是/否询问 | `y-or-n-p`、`yes-or-no-p` 的后缀与按钮 |
| **`M-x` 补全注解** | marginalia 显示的命令 docstring 首行（如 `find-file` → “编辑文件 FILENAME.”） |
| **按键弹窗 `which-key`** | 命令/分组描述（Doom 的 `:desc`）与内置标签（`prefix → 前缀`）；`C-x` 等子前缀已命名（`C-x r → +寄存器/矩形/书签`） |
| **表格头部** | `tabulated-list` 表头（如包管理、`proced` 等的 `Package → 软件包`） |
| **`C-h f` / `C-h v` 文档** | 完整命令/函数/变量/外观的 docstring（含 raw 形式回退） |
| **`C-h k` / `C-h m` 帮助** | 描述头句（“运行命令”“主模式为”）与完整 docstring |
| **`C-h b` 绑定帮助** | 小标题（`Key translations → 按键转换`、`Global Bindings → 全局绑定` 等） |

## 未汉化的内容（有意为之）

- **命令名、函数名、变量名、Lisp 符号**：如 `find-file`、`message`、`kill-ring`。
- **按键序列**：如 `C-x C-f`、`M-x`、`RET`。
- **包/库内部用于程序判断的字符串**：为保证兼容性不翻译。
- **帮助文档（docstring）与 Info 手册正文**：数量巨大，未纳入本次“界面”汉化范围。
- 少数运行时由 lambda 动态拼接、无法稳定匹配的菜单文字。

> 由于界面字符串分散在 1500+ 个 Lisp 文件与 160+ 个 C 文件中，本方案采用
> “抽取 → 机器翻译 + 人工术语校正 → 运行时查表”的方式，覆盖绝大多数可见文本，
> 并保证不会破坏程序逻辑。

## 实现原理

1. **C 层挂钩**（`src/`）
   - `src/xdisp.c`：新增变量 `chinese-l10n-table` 与查表函数
     `translate_message_string`；在 `message3`（精确匹配最终字符串）与
     `vmessage`（翻译格式串）中查表。
   - `src/editfns.c`：在 `Fformat_message` 中翻译格式串。由于 Lisp 的
     `message`、`error`、`user-error`、`warn` 都经由 `format-message`，
     因此一处即可覆盖大量消息。
   - `src/print.c`：在 `print_error_message` 中翻译错误消息（含
     `error-message` 符号属性、`signal_error` 固定串）。
   - `src/eval.c`：`verror` **不**翻译格式串，避免错误处理递归（固定错误串
     仍由 `print_error_message` 翻译）。
   - 为保证 `%s` 等参数顺序在翻译后不错位，翻译阶段把每个格式符改写为
     **位置化格式符**（如 `%1$s`、`%2$d`）。
   - **按键信息保护**：单独出现的单个字母（如 `m`、`u`、`o`、`i`、`R`、`g`、
     `x`、`C`）作为按键/变量时不会被翻译；`e.g.`/`i.e.` 等缩写整体保护。
     带 `\[命令]` 的 docstring 保持原形式，显示时由 `substitute-command-keys`
     还原为实际按键（如 `键入 \[dired-mark]` → `键入 m`）。

2. **Lisp 框架**（`src/lisp/international/chinese-l10n.el`）
   - 构建哈希表 `chinese-l10n-table`。
   - 拦截提示函数（`read-*`、`completing-read`、`format-prompt`）。
   - 递归翻译键位图中的菜单项与 `:help`。
   - 拦截 `widget-create` / `insert-button` 的 `:tag` 标签。
   - 汉化 `mode-name`、错误符号属性、启动画面文本。
   - 由 `loadup.el` 在构建时加载并随 dump 固化。

3. **词表与工具**（`l10n/`）
   - `extract.py`：从 Lisp/C 源码抽取所有用户可见字符串。
   - `translate.py`：批量机器翻译，含占位符保护、格式符校验、术语覆盖、断点续传。
   - `make-data.py`：生成 `lisp/international/chinese-l10n-data.el`。

## 启动方式

已创建控制台命令与桌面菜单项：

```sh
emacs-cn            # 中文版 Emacs（图形）
emacs-cn -nw        # 终端模式
emacs-cn file.txt   # 打开文件
```

- 命令：`~/.local/bin/emacs-cn`
- 桌面菜单：`~/.local/share/applications/emacs-cn.desktop`（应用列表里显示为 “Emacs (中文)”）
- 实际可执行文件：`/home/mhwy/Code/emacs/install31/bin/emacs`

## 构建与安装

各版本目录下分别构建：

```sh
# 31.1（Doom 用户推荐）
cd src31
./autogen.sh
./configure --prefix=/home/mhwy/Code/emacs/install31 \
            --with-x-toolkit=gtk3 --with-native-compilation \
            --without-tree-sitter
make -j16 && make install

# 30.2（独立使用）
cd src
./autogen.sh
./configure --prefix=/home/mhwy/Code/emacs/install \
            --with-x-toolkit=gtk3 --without-native-compilation \
            --without-tree-sitter
make -j16 && make install
```

## 运行

```sh
# Doom 用户：用 31.1 版（版本与 Doom 匹配）
/home/mhwy/Code/emacs/install31/bin/emacs -nw      # 终端
/home/mhwy/Code/emacs/install31/bin/emacs         # 图形界面

# 独立使用：30.2 版
/home/mhwy/Code/emacs/install/bin/emacs -nw
```

> 提示：终端或图形启动方式取决于环境；用 `-nw` 强制终端界面。

## 关闭 / 开启汉化

```elisp
(setq chinese-l10n-enable nil)   ; 恢复英文界面
```

## 扩展词表

```elisp
(chinese-l10n-add-translations
 '(("Some English string" . "某个中文串")
   ("Another %s string" . "另一个 %1$s 串")))
```

若要新增大量词条，可编辑 `l10n/` 下的流程后重新生成
`chinese-l10n-data.el`，然后重跑 `make`。

> 注意：`chinese-l10n-data.el` 更新后，`make` 不一定会自动重新 dump；
> 如界面未变化，删除 `src/src/emacs.pdmp` 后重新 `make` 即可。

## 目录

```
emacs/
├── src/                        # Emacs 30.2 源码（已含汉化改动）
├── src31/                      # Emacs 31.1 源码（已含汉化改动，Doom 推荐）
│   └── lisp/international/
│       ├── chinese-l10n.el        # 汉化框架（新增）
│       └── chinese-l10n-data.el   # 翻译词表（新增，自动生成）
├── l10n/                       # 抽取/翻译/生成工具（新增）
├── install/                    # 30.2 安装
├── install31/                  # 31.1 安装（Doom 用户使用）
├── build*.log                  # 构建日志
└── README.zh-CN.md             # 本文件
```
