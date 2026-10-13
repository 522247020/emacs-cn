#!/bin/sh
# 从预编译产物安装中文版 Emacs（安装到 /opt/emacs-cn）。
#
# 用法：
#   sh install.sh [emacs-cn-linux-x86_64.tar.zst]
#
# 说明：
#   * 产物把前缀 /opt/emacs-cn 编译进了 Emacs，必须解包到 /。
#   * 需要 root（或 sudo），以及 zstd。
#   * 新设备需与构建环境（Ubuntu 系）glibc/依赖库兼容；
#     不兼容时建议在目标机上自行编译（见 README）。
set -eu

TARBALL=${1:-emacs-cn-linux-x86_64.tar.zst}
PREFIX=/opt/emacs-cn

[ -f "$TARBALL" ] || { echo "错误：找不到 $TARBALL" >&2; exit 1; }

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

if ! command -v zstd >/dev/null 2>&1; then
  echo "错误：缺少 zstd。请先安装：" >&2
  echo "  Debian/Ubuntu: sudo apt install zstd" >&2
  echo "  Fedora:        sudo dnf install zstd" >&2
  echo "  Arch:          sudo pacman -S zstd" >&2
  exit 1
fi

echo "==> 解包到 / （安装到 $PREFIX）"
$SUDO tar --zstd -xf "$TARBALL" -C /

# ---------------------------------------------------------------- 依赖库
missing_libs() {
  ldd "$PREFIX/bin/emacs" 2>/dev/null | awk '/not found/{print $1}' | sort -u
}

# Debian/Ubuntu 常见的运行时包（不存在的会被自动过滤）
DEB_CANDIDATES="libxml2 libgnutls30 libjansson4 libharfbuzz0b libgtk-3-0
libgdk-pixbuf-2.0-0 libpango-1.0-0 libcairo2 libglib2.0-0 libatk1.0-0
libatk-bridge2.0-0 libatspi2.0-0 libepoxy0 libfribidi0 libthai0 libdatrie1
libgraphite2-3 libpixman-1-0 libfreetype6 libfontconfig1 libexpat1
libpng16-16 libjpeg-turbo8 libtiff6 libgif7 librsvg2-2 liblcms2-2 libwebp7
libx11-6 libxrender1 libxext6 libxfixes3 libxi6 libxrandr2 libxcursor1
libxcomposite1 libxdamage1 libxinerama1 libxau6 libxdmcp6 libxcb1
libxkbcommon0 libwayland-client0 libwayland-cursor0 libwayland-egl1
libsm6 libice6 libgpm2 libncursesw6 libtinfo6 libotf1 libm17n-0
libnettle8 libhogweed6 libtasn1-6 libp11-kit0 libidn2-0 libunistring5
libgmp10 libffi8 libdbus-1-3 libsystemd0 libzstd1 libsqlite3-0 libacl1
libselinux1 libpcre2-8-0 liblzma5 libbz2-1.0 libgccjit0"

install_missing() {
  miss=$(missing_libs)
  [ -n "$miss" ] || return 0
  echo "==> 检测到缺失依赖库："
  echo "$miss" | sed 's/^/    /'

  if command -v apt-get >/dev/null 2>&1; then
    pkgs=""
    for p in $DEB_CANDIDATES; do
      apt-cache show "$p" >/dev/null 2>&1 && pkgs="$pkgs $p"
    done
    if [ -n "$pkgs" ]; then
      echo "==> 用 apt 安装运行时依赖"
      $SUDO apt-get update -qq || true
      $SUDO apt-get install -y --no-install-recommends $pkgs || true
    fi
  elif command -v pacman >/dev/null 2>&1; then
    echo "==> 用 pacman 安装运行时依赖"
    ARCH_RT="gtk3 libxml2 gnutls jansson harfbuzz ncurses zlib
      libjpeg-turbo libpng giflib libtiff librsvg libxpm
      libotf m17n-lib systemd-libs dbus sqlite libffi nettle p11-kit
      libidn2 libunistring acl gpm libgccjit"
    pkgs=""
    for p in $ARCH_RT; do
      pacman -Si "$p" >/dev/null 2>&1 && pkgs="$pkgs $p"
    done
    # shellcheck disable=SC2086
    $SUDO pacman -S --needed --noconfirm $pkgs || true
  elif command -v dnf >/dev/null 2>&1; then
    echo "==> 用 dnf 安装运行时依赖"
    $SUDO dnf install -y \
      gtk3 libxml2 gnutls jansson harfbuzz ncurses-libs zlib \
      libjpeg-turbo libpng giflib libtiff librsvg2 libXpm \
      libotf m17n-lib systemd-libs dbus-libs sqlite-libs libffi \
      nettle p11-kit libidn2 libunistring acl libselinux libgccjit || true
  elif command -v zypper >/dev/null 2>&1; then
    echo "==> 用 zypper 安装运行时依赖"
    $SUDO zypper --non-interactive install \
      gtk3 libxml2 gnutls jansson harfbuzz libncurses6 zlib \
      libjpeg-turbo libpng16 giflib libtiff librsvg libXpm \
      libotf m17n-lib libsystemd0 dbus-1 sqlite3 libffi8 \
      libnettle8 p11-kit libidn2 unistring libacl1 libselinux1 libgccjit0 || true
  else
    echo "未能识别包管理器，请手动安装上面的库。"
  fi
}

install_missing

echo "==> 再次检查依赖"
miss=$(missing_libs)
if [ -n "$miss" ]; then
  echo "仍缺少以下库（请安装对应软件包）："
  echo "$miss" | sed 's/^/    /'
  echo "提示：若发行版/glibc 差异较大，建议在目标机上重新编译（见 README）。"
else
  echo "依赖库齐全。"
fi

# ---------------------------------------------------------------- 命令与菜单
echo "==> 创建 emacs-cn 命令"
if [ -w /usr/local/bin ]; then
  ln -sf "$PREFIX/bin/emacs" /usr/local/bin/emacs-cn
else
  $SUDO ln -sf "$PREFIX/bin/emacs" /usr/local/bin/emacs-cn
fi

echo "==> 创建桌面菜单项"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/emacs-cn.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Emacs (中文)
Name[zh_CN]=Emacs 中文版
GenericName=文本编辑器
Comment=中文界面的 GNU Emacs 31.1
Exec=/opt/emacs-cn/bin/emacs %F
Terminal=false
Icon=emacs
Categories=Development;TextEditor;IDE;
MimeType=text/plain;
StartupWMClass=Emacs
EOF

echo
echo "安装完成："
echo "  可执行文件: $PREFIX/bin/emacs"
echo "  命令:       emacs-cn        （终端用 emacs-cn -nw）"
"$PREFIX/bin/emacs" --version 2>/dev/null | head -1 || true
