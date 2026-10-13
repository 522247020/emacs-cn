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

依赖安装脚本同时支持 **Arch** 与 **Debian/Ubuntu**（自动识别包管理器）：

```sh
# 1) 安装构建依赖（Arch: pacman；Debian/Ubuntu: apt）
sh ci/install-deps.sh

# 2) 构建（自动处理原生编译回退；PREFIX/NATIVE/JOBS 可调）
PREFIX=/home/mhwy/Code/emacs/install31 sh ci/build-emacs.sh
```

也可手动构建：

```sh
cd src
./autogen.sh
./configure --prefix=/home/mhwy/Code/emacs/install31 \
            --with-x-toolkit=gtk3 --with-native-compilation \
            --without-tree-sitter
make -j16
make install
```

> `ci/install-deps.sh` 在各发行版上安装的包：
> - **Arch**：`base-devel autoconf automake texinfo pkgconf zstd gnutls libxml2 jansson gmp gtk3 harfbuzz ncurses zlib libjpeg-turbo libpng giflib libtiff librsvg libxpm libotf m17n-lib systemd-libs dbus sqlite libffi nettle p11-kit libidn2 libunistring acl gpm libgccjit`
>   （脚本会自动跳过仓库中不存在的包；`libselinux` 在 Arch 官方仓库没有，SELinux 支持为可选，会自动省略）
> - **Debian/Ubuntu**：`build-essential autoconf automake texinfo pkg-config zstd libgnutls28-dev libxml2-dev libjansson-dev libgmp-dev libgtk-3-dev libharfbuzz-dev libncurses-dev zlib1g-dev libjpeg-dev libpng-dev libgif-dev libtiff-dev librsvg2-dev libxpm-dev libotf-dev libm17n-dev libsystemd-dev libdbus-1-dev libsqlite3-dev libffi-dev libnettle-dev libp11-kit-dev libidn2-dev libunistring-dev libacl1-dev libselinux1-dev libgpm-dev` + `libgccjit-<ver>-dev`

## 自动构建（GitHub / Gitea）

仓库已内置 CI，构建产物为可移植压缩包
`emacs-cn-linux-x86_64.tar.zst`（内含 `/opt/emacs-cn` 目录树）：

| 平台 | 工作流文件 | 说明 |
| --- | --- | --- |
| GitHub | `.github/workflows/build.yml` | 用 GitHub 托管 runner，打 tag 时自动创建 Release |
| Gitea | `.gitea/workflows/build.yml` | 用自建 `act_runner`；**不依赖外部 action**（`git clone` + Gitea API），打 tag 时自动建 Release |

> **Gitea 版为何不用 `actions/checkout` / `actions/upload-artifact`**：
> 这些 action 默认从 `github.com` 拉取。若 runner 无法访问 github.com
> （国内网络常见，报 `lookup github.com ... server misbehaving`），工作流会直接失败。
> 所以 Gitea 版改为：用 `git clone`（走你自己的 Gitea 服务器）取代码，
> 用 `curl` 调 Gitea API 发 Release，全程不需要外网 action。
>
> 也可在 Gitea 的 `app.ini` 里把 action 源指向可访问的镜像：
> ```ini
> [actions]
> DEFAULT_ACTIONS_URL = https://gitea.com
> ```
> 前提是 runner 能访问 `gitea.com`。

两者都调用同一个脚本 `ci/build-emacs.sh`（可用 `PREFIX`、`NATIVE`、`JOBS`
环境变量控制）。触发方式：推送到 `main`、提交 PR、打 `v*` 标签，或在页面手动运行。

### 自动打 tag 与发布

产物名固定为 `emacs-cn-linux-x86_64.tar.zst`，发布规则：

- **推送到 `main`**：构建成功后，读取仓库根目录的 `VERSION` 文件，
  自动创建 `v<VERSION>` 标签（若已存在则跳过）与同名 Release，并附上产物。
- **推送 `v*` 标签**：为该标签创建 Release 并附上产物。
- **发布新版本**：修改 `VERSION`（如 `31.1.50-cn1` → `31.1.50-cn2`）后推送到 `main` 即可。

使用产物（**按发行版选对应包**）：

| 产物 | 适用 | 说明 |
| --- | --- | --- |
| `emacs-cn-linux-x86_64.tar.zst` | Debian / Ubuntu | 在 Ubuntu runner 上构建 |
| `emacs-cn-arch-x86_64.tar.zst` | Arch / Manjaro / Omarchy | 在 archlinux 容器里构建 |

```sh
# 解包（需要写入 /opt）
sudo tar --zstd -xf emacs-cn-<distro>-x86_64.tar.zst -C /
/opt/emacs-cn/bin/emacs -nw
```

> **为什么必须分发行版**：Emacs 是动态链接的，依赖系统的 soname。
> 例如 `libxml2`：Ubuntu 是 `libxml2.so.2`，而较新的 Arch 是
> `libxml2.so.16`。用 Ubuntu 版在 Arch 上跑会报
> `libxml2.so.2: cannot open shared object file`——装 `libxml2` 也没用。
> 所以请用对应发行版的产物；不确定就**在目标机上自行编译**（见下）。
>
> 另：产物把安装前缀 `/opt/emacs-cn` 编进了路径，必须解到该位置。
> 想换路径就改 `ci/build-emacs.sh` 的 `PREFIX` 后重新构建。

### 在目标机上自行编译（最稳）

任何发行版都适用：

```sh
sh ci/install-deps.sh                          # Arch: pacman；Debian: apt
PREFIX=$HOME/.local/emacs-cn sh ci/build-emacs.sh
$HOME/.local/emacs-cn/bin/emacs -nw
```

### GitHub 与 Gitea 的主要差异

| 方面 | GitHub Actions | Gitea Actions |
| --- | --- | --- |
| Runner | 官方托管 `ubuntu-latest`，无需自备 | 需自建 `act_runner`，`runs-on` 必须匹配 runner 标签（默认 `ubuntu-latest`） |
| 工作流目录 | `.github/workflows/` | `.gitea/workflows/`（也可配置读取 `.github/workflows/`） |
| Action 来源 | GitHub Marketplace | 默认从 `gitea.com` 镜像拉取；`actions/checkout`、`actions/upload-artifact` 可用，部分 GitHub 专属 action 不可用 |
| 自动 token | `secrets.GITHUB_TOKEN` | 提供 `GITHUB_TOKEN`（兼容）；不同版本可能要另配 secret |
| Artifact | 内置，`upload-artifact`，默认保留 90 天 | 需服务端开启并配置 artifact 存储 |
| Release | `softprops/action-gh-release` 或 `gh` | Gitea REST API 或 `release-action` |
| 容器镜像 | GHCR（`ghcr.io`） | Gitea 容器仓库 |
| Pages | 内置 GitHub Pages | 无内置 Pages，需另配 |
| 资源/计费 | 免费额度，超出计费 | 用你自己的 runner |

**结论**：构建逻辑完全一样（同一脚本），主要差别在 **runner 来源**、
**Action 的拉取来源** 与 **发布/制品存储**。Gitea 上也能跑，但需要先部署
`act_runner`，制品/Release 走 Gitea 自己的接口。

## 更新 Emacs / Doom

### 更新 Emacs 源码

汉化由三部分组成，便于跟着上游更新：

| 组成 | 位置 | 说明 |
| --- | --- | --- |
| 代码补丁 | `patches/emacs-cn.patch` | 对上游约 10 个文件的小改动 + 新增 `chinese-l10n.el` |
| 翻译词表 | `src/lisp/international/chinese-l10n-data.el` | 约 6.5 万条，与版本无关 |
| 脚本 | `ci/apply-l10n.sh`、`ci/update-emacs.sh` | 套补丁 / 拉取上游并更新 |

跟进上游（以 `emacs-31` 为例）：

```sh
# 1) 拉取上游新源码、套用汉化；旧源码移到 src.old
sh ci/update-emacs.sh emacs-31

# 2) 查看变化并构建验证
sh ci/install-deps.sh
cd src && ./autogen.sh
./configure --prefix=/home/mhwy/Code/emacs/install31 \
            --with-x-toolkit=gtk3 --with-native-compilation --without-tree-sitter
make -j"$(nproc)"

# 3) 没问题后删除 src.old 并提交
cd .. && rm -rf src.old && git add -A && git commit -m "upgrade emacs"
```

如果上游改动导致补丁冲突，`patch` 会生成 `.rej` 文件，按提示手工合并即可。
改动集中在：

- C：`src/xdisp.c`、`src/editfns.c`、`src/print.c`、`src/lisp.h`
- Lisp：`lisp/loadup.el`、`lisp/startup.el`、`lisp/subr.el`、`lisp/help.el`、`lisp/help-fns.el`
- 新增：`lisp/international/chinese-l10n.el`、`chinese-l10n-data.el`

只改汉化、不动上游时，直接改 `src/` 里的文件，再重新导出补丁（对照一份
纯净上游源码）：

```sh
# /tmp/emacs-base 为对应版本的上游源码
cd /home/mhwy/Code/emacs
git ls-files src/ | while IFS= read -r f; do
  rel=${f#src/}
  [ "$rel" = lisp/international/chinese-l10n-data.el ] && continue
  base=/tmp/emacs-base/$rel
  if [ -f "$base" ]; then cmp -s "$base" "$f" || diff -u --label "a/$rel" --label "b/$rel" "$base" "$f"
  else diff -u --label /dev/null --label "b/$rel" /dev/null "$f"; fi
done > patches/emacs-cn.patch
```

### 更新 Doom

Doom 的状态是按 Emacs **主/次版本**存的，更新时注意：

1. **Doom 自身更新**：
   ```sh
   ~/.config/emacs/bin/doom upgrade    # 或 git -C ~/.config/emacs pull
   ~/.config/emacs/bin/doom sync
   ```
2. **Emacs 更新后必须用同一份 Emacs 跑 `doom sync`**：会重新生成
   `init.<major>.<minor>.el` 与 `straight/build-<major>.<minor>`：
   ```sh
   EMACS=/home/mhwy/Code/emacs/install31/bin/emacs \
     ~/.config/emacs/bin/doom sync
   ```
3. **版本要对上**：Doom 的 `build-31.1` / `init.31.1.el` 对应 Emacs 31.1；
   升到 31.2 就需要重新 `doom sync` 生成 `build-31.2`。
4. 若更新后 which-key / marginalia 汉化失效，确认 `loadup.el` 里仍有
   `(load "international/chinese-l10n")`。

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
