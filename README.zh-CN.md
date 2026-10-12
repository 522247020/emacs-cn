# GNU Emacs 中文汉化版

本仓库是**简体中文界面版 GNU Emacs**。除命令名、函数名、变量名和按键序列外，
尽可能把用户可见的界面信息翻译为中文。

- 版本：**Emacs 31.1.50**（基于 `emacs-31` 分支，主/次版本 31.1）
- 源码（含汉化改动）：`src/`
- 已安装的中文版：`install31/`
- 汉化工具与词表：`l10n/`
- 翻译词条：**约 65,800 条**（`src/lisp/international/chinese-l10n-data.el`，约 25MB）
  - 含约 **22,800 条完整 docstring** 与 **13,000 条 raw docstring**，
    供 `C-h f` / `C-h v` / `C-h k` / `C-h m` 显示中文

> 为什么安装目录叫 `install31`：构建时 `--prefix` 写死为
> `/home/mhwy/Code/emacs/install31`，改名会导致安装好的 Emacs 找不到自己的
> lisp/data 路径，故保持该名字（源码目录已改为 `src`）。

## 启动方式

已创建控制台命令与桌面菜单项：

```sh
emacs-cn            # 中文版 Emacs（图形界面）
emacs-cn -nw        # 终端模式
emacs-cn file.txt   # 打开文件
```

- 命令：`~/.local/bin/emacs-cn`
- 桌面菜单：`~/.local/share/applications/emacs-cn.desktop`
  （应用列表里显示为 “Emacs (中文)”）
- 实际可执行文件：`/home/mhwy/Code/emacs/install31/bin/emacs`

## 与 Doom Emacs 的兼容性

Doom 的生成状态是**按 Emacs 主/次版本区分**的：

```
~/.config/emacs/.local/etc/@/init.31.1.el      # profile 初始化文件
~/.config/emacs/.local/straight/build-31.1/    # 包编译产物
~/.config/emacs/eln-cache/31.1-<hash>/         # 原生编译缓存
```

本汉化版正是 **31.1**，与本机 Doom 匹配。实测：

```
Doom loaded 143 packages across 37 modules
```

若用不同版本的 Emacs（例如 30.2）加载这套 Doom 配置，会因找不到
`init.<版本>.el` 报 `doom-nosync-error` 与 `(void-variable doom-modules)`；
那不是汉化问题，而是版本不匹配，需要用该 Emacs 重新执行 `doom sync`。

## 关于 `M-x` 与按键弹窗

- **`M-x` 补全列表**：命令名本身保持英文；右侧注解由 marginalia 提供，
  其中命令的 docstring 首行已汉化。
- **按键弹窗（which-key）**：
  - 有自定义描述的命令/分组（Doom 的 `:desc`/`:prefix`）→ 显示中文描述；
  - 没有自定义描述的命令（典型如内置的 `C-x` 前缀）→ 显示其中文
    **docstring 首行**，而不是英文命令名；
  - 常用子前缀已命名：`C-x r → +寄存器/矩形/书签`、`C-x t → +标签页`、
    `C-x n → +缩窄`、`C-x x → +缓冲区` 等。

如需改回 which-key 显示命令名：

```elisp
(advice-remove 'which-key--maybe-add-docstring
               #'chinese-l10n--wk-maybe-add-docstring)
```

## 已汉化的内容

| 界面元素 | 说明 |
| --- | --- |
| 回显区消息 / `message` | 如 “正在保存文件…”、“缓冲区开头” |
| 错误与警告信息 | `error`、`user-error`、`warn`、C 层错误符号 |
| 迷你缓冲区提示 | `read-*`、`completing-read`、`format-prompt` 等 |
| 菜单栏 / 工具栏 / 弹出菜单 | 菜单项标签与 `:help` 工具提示 |
| 启动画面 / 关于画面 | 图形版与终端版 |
| 模式行模式名 | 如 `Fundamental → 基本`、`Compilation → 编译` |
| Customize 等部件按钮 | `:tag` 标签，如 `Apply → 应用` |
| 是/否询问 | `y-or-n-p`、`yes-or-no-p` 的后缀与按钮 |
| `M-x` 补全注解 | marginalia 显示的命令 docstring 首行 |
| 按键弹窗 `which-key` | 命令/分组描述与内置标签 |
| 表格头部 | `tabulated-list` 表头（`Package → 软件包` 等） |
| `C-h f` / `C-h v` | 完整命令/函数/变量/外观的 docstring |
| `C-h k` / `C-h m` | 描述头句与完整 docstring |
| `C-h b` 绑定帮助 | 小标题（`Key translations → 按键转换` 等） |

## 未汉化的内容（有意为之）

- **命令名、函数名、变量名、Lisp 符号**：如 `find-file`、`kill-ring`。
- **按键序列**：如 `C-x C-f`、`M-x`、`RET`（这些必须保持原样，否则无法操作）。
- **包/库内部用于程序判断的字符串**：为保证兼容性不翻译。
- **Info 手册正文**（`C-h i`、`C-h r`）：Texinfo 文档体量极大，不在本次界面汉化范围。
- 少数运行时由 lambda 拼接、无法稳定匹配的文本，以及个别机翻瑕疵。

## 实现原理

1. **C 层挂钩**
   - `src/src/xdisp.c`：新增变量 `chinese-l10n-table` 与查表函数
     `translate_message_string`；在 `message3`（精确匹配）与
     `vmessage`（翻译格式串）中查表。
   - `src/src/editfns.c`：在 `Fformat_message` 中翻译格式串，覆盖 Lisp 的
     `message`、`error`、`user-error`、`warn`。
   - `src/src/print.c`：在 `print_error_message` 中翻译错误消息。
   - `src/src/eval.c`：`verror` 不翻译格式串，避免错误处理递归。

2. **Lisp 框架**（`src/lisp/international/chinese-l10n.el`）
   - 构建哈希表 `chinese-l10n-table`。
   - 拦截提示函数、键位图菜单、`widget-create`/`insert-button` 的 `:tag`。
   - 汉化 `mode-name`、错误符号属性、启动画面。
   - 通过 `documentation` / `documentation-property` 的 advice 翻译完整 docstring
     （同时处理 help 缓冲区使用的 raw 形式）。
   - 由 `loadup.el` 在构建时加载并随 dump 固化。

3. **词表与工具**（`l10n/`）
   - `extract.py`：从 Lisp/C 源码抽取用户可见字符串。
   - `translate.py`：批量机器翻译，含占位符保护、格式符校验、术语覆盖、断点续传。
   - `make-data.py`：生成 `src/lisp/international/chinese-l10n-data.el`。

### 翻译中的两个关键保护

- **格式参数位置化**：把 `%s`/`%d` 改写为 `%1$s`/`%2$d`，避免译文语序变化导致参数错位。
- **按键信息保护**：单独出现的单个字母（`m`、`u`、`o`、`i`、`R`、`g`、`x`、`C`…）
  作为按键/变量时**不翻译**；`e.g.`/`i.e.` 等缩写整体保护；带 `\[命令]` 的
  docstring 保持原形式，显示时由 `substitute-command-keys` 还原为实际按键。

## 构建与安装

```sh
cd src
./autogen.sh
./configure --prefix=/home/mhwy/Code/emacs/install31 \
            --with-x-toolkit=gtk3 --with-native-compilation \
            --without-tree-sitter
make -j16
make install
```

## 运行

```sh
/home/mhwy/Code/emacs/install31/bin/emacs -nw   # 终端
/home/mhwy/Code/emacs/install31/bin/emacs       # 图形界面
```

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
`src/lisp/international/chinese-l10n-data.el`，然后重跑 `make`。

> 注意：`chinese-l10n-data.el` 更新后 `make` 不一定会自动重新 dump；
> 如界面未变化，删除 `src/src/emacs.pdmp` 后重新 `make` 即可。

## 目录

```
emacs/
├── .gitignore
├── README.zh-CN.md
├── src/                        # Emacs 31.1.50 源码（已含汉化改动）
│   ├── lisp/international/
│   │   ├── chinese-l10n.el         # 汉化框架（新增）
│   │   └── chinese-l10n-data.el    # 翻译词表（新增，自动生成）
│   └── src/                    # Emacs 的 C 源码目录
├── l10n/                       # 抽取/翻译/生成工具
│   ├── extract.py
│   ├── translate.py
│   ├── make-data.py
│   └── *.txt                   # 抽取到的待翻译文本
└── install31/                  # 已安装的中文版 Emacs（git 忽略）
```
