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

# 图形后端：x11（默认，GTK3/X11）或 pgtk（纯 GTK，原生 Wayland，即 emacs-wayland）
TOOLKIT=${TOOLKIT:-x11}
case "$TOOLKIT" in
  pgtk|wayland)
    TOOLKIT=pgtk; TOOLKIT_OPT=--with-pgtk; VARIANT=-pgtk
    PKGNAME=${PKGNAME:-emacs-cn-wayland} ;;
  *)
    TOOLKIT=x11; TOOLKIT_OPT=--with-x-toolkit=gtk3; VARIANT=
    PKGNAME=${PKGNAME:-emacs-cn} ;;
esac

# 按 发行版 + 架构 (+ 变体) 自动命名产物（可用 OUT 覆盖）
ARCH=$(uname -m)   # x86_64 / aarch64
if [ -z "${OUT:-}" ]; then
  ID=""; ID_LIKE=""
  # shellcheck disable=SC1091
  [ -r /etc/os-release ] && . /etc/os-release 2>/dev/null || true
  case "$ID $ID_LIKE" in
    *arch*|*manjaro*|*omarchy*) OUT=emacs-cn-arch-$ARCH$VARIANT.tar.zst ;;
    *debian*|*ubuntu*|*mint*|*pop*) OUT=emacs-cn-debian-$ARCH$VARIANT.tar.zst ;;
    *) OUT=emacs-cn-linux-$ARCH$VARIANT.tar.zst ;;
  esac
fi

case "$NATIVE" in
  yes|true|1) NATIVE_OPT=--with-native-compilation ;;
  *)          NATIVE_OPT=--without-native-compilation ;;

esac

echo "==> 源码目录: $ROOT/src"
cd "$ROOT/src"

# 套用中文手册译文（若存在），使构建出的 Info 手册为中文
if [ -d "$ROOT/l10n/manual-zh" ]; then
  sh "$ROOT/ci/apply-manual-zh.sh"
fi

echo "==> autogen"
./autogen.sh

configure_with() {
  ./configure \
    --prefix="$PREFIX" \
    $TOOLKIT_OPT \
    "$@" \
    --without-tree-sitter
}

echo "==> configure (prefix=$PREFIX, native=$NATIVE, toolkit=$TOOLKIT)"
if [ "$NATIVE_OPT" = --with-native-compilation ]; then
  # 尝试原生编译；libgccjit 不可用时自动回退
  if configure_with --with-native-compilation; then
    echo "==> 已启用原生编译"
  else
    echo "==> 原生编译不可用（缺少 libgccjit），回退到 --without-native-compilation"
    configure_with --without-native-compilation
  fi
else
  configure_with --without-native-compilation
fi

echo "==> make -j$JOBS"
make -j"$JOBS"

echo "==> 快速自检（词典是否加载）"
./src/emacs -Q --batch --eval \
  '(princ (format "chinese-l10n-table entries = %s\n" (hash-table-count chinese-l10n-table)))'

echo "==> make install DESTDIR=$ROOT/stage"
rm -rf "$ROOT/stage"
make install DESTDIR="$ROOT/stage"

echo "==> 打包 (tar.zst)"
cd "$ROOT/stage"
tar --zstd -cf "$ROOT/$OUT" .
echo "==> 完成: $ROOT/$OUT"
ls -lh "$ROOT/$OUT"

echo "==> 生成发行版原生包"
PKGVER=$(cat "$ROOT/VERSION" 2>/dev/null | tr -d '\n' || true)
[ -n "$PKGVER" ] || PKGVER=0
sh "$ROOT/ci/make-package.sh" "$ROOT/stage" "$PREFIX" "$PKGVER" "$ROOT" "$PKGNAME"
