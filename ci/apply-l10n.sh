#!/bin/sh
# 把中文汉化套用到一份 Emacs 源码目录。
#
# 用法：
#   ci/apply-l10n.sh <emacs-source-dir>
#
# 做了两件事：
#   1. 套用 patches/emacs-cn.patch（C/Lisp 改动 + 新增 chinese-l10n.el）
#   2. 复制翻译词表 chinese-l10n-data.el
#
# 说明：补丁基于 emacs-31 的 d6eb754 生成。套用到更新的版本时可能有
# 少量 hunk 冲突，按提示手工合并即可（改动都很小）。
set -eu

HERE=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${1:?用法: ci/apply-l10n.sh <emacs-source-dir>}

if [ ! -f "$TARGET/src/xdisp.c" ]; then
  echo "错误：$TARGET 看起来不是 Emacs 源码目录（缺少 src/xdisp.c）" >&2
  exit 1
fi

DATA="$HERE/src/lisp/international/chinese-l10n-data.el"
if [ ! -f "$DATA" ]; then
  echo "错误：找不到翻译词表 $DATA" >&2
  exit 1
fi

echo "==> 套用补丁到 $TARGET"
patch -p1 -d "$TARGET" < "$HERE/patches/emacs-cn.patch"

echo "==> 复制翻译词表"
cp "$DATA" "$TARGET/lisp/international/chinese-l10n-data.el"

echo "==> 完成。可进入 $TARGET 执行 autogen/configure/make 构建。"
