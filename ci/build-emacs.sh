#!/bin/sh
# 构建并打包中文版 Emacs。
#
# 环境变量：
#   PREFIX   安装前缀（默认 /opt/emacs-cn，会写入二进制，解包需解到同一路径）
#   NATIVE   yes/no，是否启用原生编译（默认 yes，需要 libgccjit）
#   JOBS     并行数（默认 nproc）
#
# 产物：
#   emacs-cn-linux-x86_64.tar.zst  —— 含 PREFIX 目录树，可解到 / 使用
#   stage/                          —— DESTDIR 暂存目录
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PREFIX=${PREFIX:-/opt/emacs-cn}
NATIVE=${NATIVE:-yes}
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 2)}

case "$NATIVE" in
  yes|true|1) NATIVE_OPT=--with-native-compilation ;;
  *)          NATIVE_OPT=--without-native-compilation ;;
esac

echo "==> 源码目录: $ROOT/src"
cd "$ROOT/src"

echo "==> autogen"
./autogen.sh

echo "==> configure (prefix=$PREFIX, native=$NATIVE)"
./configure \
  --prefix="$PREFIX" \
  --with-x-toolkit=gtk3 \
  "$NATIVE_OPT" \
  --without-tree-sitter

echo "==> make -j$JOBS"
make -j"$JOBS"

echo "==> 快速自检（词典是否加载）"
./src/emacs -Q --batch --eval \
  '(princ (format "chinese-l10n-table entries = %s\n" (hash-table-count chinese-l10n-table)))'

echo "==> make install DESTDIR=$ROOT/stage"
rm -rf "$ROOT/stage"
make install DESTDIR="$ROOT/stage"

echo "==> 打包"
cd "$ROOT/stage"
tar --zstd -cf "$ROOT/emacs-cn-linux-x86_64.tar.zst" .
echo "==> 完成: $ROOT/emacs-cn-linux-x86_64.tar.zst"
ls -lh "$ROOT/emacs-cn-linux-x86_64.tar.zst"
