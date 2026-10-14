#!/bin/sh
# 从 DESTDIR 暂存目录生成发行版原生包。
#
# 用法：ci/make-package.sh <stage-dir> <prefix> <version> <out-dir> [pkgname]
#   stage-dir  make install DESTDIR=... 的暂存目录（内含 <prefix>/...）
#   prefix     编译时的 --prefix（如 /opt/emacs-cn）
#   version    版本号（如 31.1.50-cn2）
#   out-dir    产物输出目录
#   pkgname    包名（默认 emacs-cn；Wayland 版为 emacs-cn-wayland）
#
# Debian/Ubuntu → <pkgname>_<version>_<arch>.deb
# Arch/Manjaro  → <pkgname>-<version>-<arch>.pkg.tar.zst
set -eu

STAGE=${1:?用法: make-package.sh <stage-dir> <prefix> <version> <out-dir> [pkgname]}
PREFIX=${2:?}
PKGVER=${3:?}
OUTDIR=${4:?}
PKGNAME=${5:-emacs-cn}

[ -d "$STAGE" ] || { echo "错误：找不到暂存目录 $STAGE" >&2; exit 1; }
mkdir -p "$OUTDIR"
REL=${PREFIX#/}          # /opt/emacs-cn -> opt/emacs-cn

# 架构：deb 用 amd64/arm64；pacman 用 x86_64/aarch64
case "$(uname -m)" in
  x86_64|amd64)   DEBARCH=amd64 ; ARCHPKG=x86_64 ;;
  aarch64|arm64)  DEBARCH=arm64 ; ARCHPKG=aarch64 ;;
  armv7l|armhf)   DEBARCH=armhf ; ARCHPKG=armv7h ;;
  *)              DEBARCH=$(uname -m) ; ARCHPKG=$(uname -m) ;;
esac

ID=""; ID_LIKE=""
OS_RELEASE=${OS_RELEASE:-/etc/os-release}
# shellcheck disable=SC1091
[ -r "$OS_RELEASE" ] && . "$OS_RELEASE" 2>/dev/null || true
# 可用 PKG_DISTRO 覆盖（测试用，如 PKG_DISTRO=debian）
[ -n "${PKG_DISTRO:-}" ] && ID="$PKG_DISTRO"
# .deb 文件名里的发行版标识
case "$ID $ID_LIKE" in
  *arch*|*manjaro*|*omarchy*) DISTRO_TAG=arch ;;
  *ubuntu*|*mint*|*pop*)      DISTRO_TAG=ubuntu ;;
  *debian*)                   DISTRO_TAG=debian ;;
  *)                          DISTRO_TAG=$ID ;;
esac

# 兜底依赖（当无法用 ldd 推导时使用）。用 "A | B" 兼容 Debian/Ubuntu
# 的包名差异：Debian 是 libjpeg62-turbo，Ubuntu 是 libjpeg-turbo8，等等。
# libgccjit 是运行时 dlopen 的（原生编译用），列为可选 Recommends。
DEB_DEPENDS="libc6, libgtk-3-0, libgnutls30 | libgnutls30t64, libxml2, \
libjansson4, libharfbuzz0b, libncursesw6, zlib1g, \
libjpeg62-turbo | libjpeg-turbo8, libpng16-16, libgif7 | libgif4, \
libtiff6 | libtiff5, librsvg2-2, libxpm4, libotf1, libm17n-0, libsystemd0, \
libdbus-1-3, libsqlite3-0, libffi8 | libffi7, libnettle8 | libnettle7, \
libp11-kit0, libidn2-0, libunistring5 | libunistring2, libacl1, libselinux1, \
libgpm2"
DEB_RECOMMENDS="libgccjit0"

ARCH_DEPENDS="gtk3 gnutls libxml2 jansson harfbuzz ncurses zlib libjpeg-turbo \
libpng giflib libtiff librsvg libxpm libotf m17n-lib systemd-libs dbus sqlite \
libffi nettle p11-kit libidn2 libunistring acl gpm libgccjit"

if [ "$PKGNAME" = emacs-cn ]; then
  PKGDESC="Chinese localized GNU Emacs (中文版 Emacs)"
else
  PKGDESC="Chinese localized GNU Emacs, pure-GTK/Wayland build (Wayland 中文版)"
fi

# 用 ldd + dpkg -S 从实际二进制推导运行时依赖：在哪个发行版构建，
# 就得到该发行版的正确包名（Debian 上得到 libjpeg62-turbo 而非 libjpeg-turbo8）。
gen_deb_depends() {
  main=""
  for f in "$STAGE/$REL/bin/emacs" "$STAGE/$REL/bin"/emacs-*; do
    if [ -f "$f" ] && head -c 4 "$f" 2>/dev/null | grep -q ELF; then
      main="$f"; break
    fi
  done
  if [ -n "$main" ] && command -v ldd >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1; then
    deps=""
    for lib in $(ldd "$main" 2>/dev/null | sed -n 's/.*=> \/\([^ ]*\).*/\/\1/p'); do
      p=$(dpkg -S "$lib" 2>/dev/null | head -1 | cut -d: -f1)
      [ -n "$p" ] && deps="$deps $p"
    done
    deps=$(printf '%s\n' $deps | sort -u | paste -sd, -)
    if [ -n "$deps" ]; then printf '%s' "$deps"; return 0; fi
  fi
  printf '%s' "$DEB_DEPENDS"
}

make_deb() {
  echo "==> 生成 .deb"
  if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "警告：未安装 dpkg-deb，跳过 .deb 生成"
    return 0
  fi
  DEBVER=$(printf '%s' "$PKGVER" | tr '-' '~')
  tmp=$(mktemp -d)
  mkdir -p "$tmp/DEBIAN"
  cp -a "$STAGE/." "$tmp/"
  isize=$(du -sk "$tmp" | cut -f1)
  {
    echo "Package: $PKGNAME"
    echo "Version: $DEBVER"
    echo "Section: editors"
    echo "Priority: optional"
    echo "Architecture: $DEBARCH"
    echo "Maintainer: emacs-cn <emacs-cn@localhost>"
    echo "Installed-Size: $isize"
    echo "Depends: $(gen_deb_depends | tr -d '\\\n' | sed 's/ *$//')"
    echo "Recommends: $DEB_RECOMMENDS"
    [ "$PKGNAME" = emacs-cn ] || { echo "Conflicts: emacs-cn"; echo "Provides: emacs-cn"; }
    echo "Description: $PKGDESC"
    echo " A Chinese-localized build of GNU Emacs.  The user interface, docstrings"
    echo " and manuals are translated into Simplified Chinese; command names and key"
    echo " sequences are kept unchanged."
  } > "$tmp/DEBIAN/control"
  out="$OUTDIR/${PKGNAME}-${DISTRO_TAG}_${DEBVER}_${DEBARCH}.deb"
  dpkg-deb --build --root-owner-group "$tmp" "$out" >/dev/null 2>&1 \
    || dpkg-deb -b "$tmp" "$out" >/dev/null
  echo "已生成 $out"
  rm -rf "$tmp"
}

make_pacman() {
  echo "==> 生成 pacman 包"
  tmp=$(mktemp -d)
  mkdir -p "$tmp/$REL"
  cp -a "$STAGE/$REL/." "$tmp/$REL/"
  isize=$(du -sb "$tmp" | cut -f1)
  {
    echo "pkgname = $PKGNAME"
    echo "pkgbase = $PKGNAME"
    echo "pkgver = $PKGVER"
    echo "pkgdesc = $PKGDESC"
    echo "url = https://www.gnu.org/software/emacs/"
    echo "builddate = $(date +%s)"
    echo "packager = emacs-cn"
    echo "size = $isize"
    echo "arch = $ARCHPKG"
    echo "license = GPL-3.0-or-later"
    [ "$PKGNAME" = emacs-cn ] || { echo "conflicts = emacs-cn"; echo "provides = emacs-cn"; }
    for p in $ARCH_DEPENDS; do echo "depend = $p"; done
  } > "$tmp/.PKGINFO"
  out="$OUTDIR/${PKGNAME}-${PKGVER}-${ARCHPKG}.pkg.tar.zst"
  ( cd "$tmp" && tar --zstd -cf "$out" .PKGINFO "$REL" )
  echo "已生成 $out"
  rm -rf "$tmp"
}

case "$ID $ID_LIKE" in
  *arch*|*manjaro*|*omarchy*) make_pacman ;;
  *debian*|*ubuntu*|*mint*|*pop*) make_deb ;;
  *)
    echo "提示：未识别的发行版（$ID），跳过原生打包（仍可用 tar.zst 产物）"
    ;;
esac
