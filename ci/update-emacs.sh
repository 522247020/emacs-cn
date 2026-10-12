#!/bin/sh
# 更新 Emacs 源码到指定上游 ref，并自动套用中文汉化。
#
# 用法：
#   ci/update-emacs.sh [ref]        # 默认 emacs-31；ref 可为分支/tag/提交
#   UPSTREAM=<url> ci/update-emacs.sh emacs-32
#
# 结果：旧源码移到 src.old/，新源码放在 src/，并已套用汉化与词表。
#       确认无误后再删除 src.old 并提交。
set -eu

HERE=$(cd "$(dirname "$0")/.." && pwd)
REF=${1:-emacs-31}
UPSTREAM=${UPSTREAM:-https://github.com/emacs-mirror/emacs.git}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> 获取上游 $REF"
echo "    $UPSTREAM"
if ! git clone -q --depth 1 --branch "$REF" "$UPSTREAM" "$TMP/emacs" 2>/dev/null; then
  mkdir -p "$TMP/emacs"
  git -C "$TMP/emacs" init -q
  git -C "$TMP/emacs" remote add origin "$UPSTREAM"
  git -C "$TMP/emacs" fetch -q --depth 1 origin "$REF"
  git -C "$TMP/emacs" checkout -q FETCH_HEAD
fi
VERSION=$(grep -m1 'AC_INIT(\[GNU Emacs\]' "$TMP/emacs/configure.ac" | sed -E 's/.*\[([0-9.]+)\].*/\1/')
echo "==> 上游版本: $VERSION"

# 去掉嵌套 .git，避免成为子仓库
rm -rf "$TMP/emacs/.git"

# 套用汉化（会把词表从旧 src 复制过去）
sh "$HERE/ci/apply-l10n.sh" "$TMP/emacs"

echo "==> 替换 src/（旧目录保留为 src.old）"
rm -rf "$HERE/src.old"
mv "$HERE/src" "$HERE/src.old"
mv "$TMP/emacs" "$HERE/src"

cat <<EOF

==> 完成，上游版本 $VERSION 已套用汉化。

后续步骤：
  1) git status / git diff --stat  查看变化
  2) 构建验证：
       cd src && ./autogen.sh
       ./configure --prefix=/home/mhwy/Code/emacs/install31 \\
                   --with-x-toolkit=gtk3 --with-native-compilation --without-tree-sitter
       make -j\$(nproc)
  3) 确认无误后删除 src.old，并按需提升 VERSION（发新版本）
EOF
