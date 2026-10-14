#!/bin/sh
# 安装构建「中文版 Emacs」所需的依赖，支持 Arch 与 Debian/Ubuntu。
#
# 用法：
#   sh ci/install-deps.sh
#
# 说明：
#   * 需要 root（或 sudo）。
#   * 若不需要原生编译，可不装 libgccjit（构建脚本会自动回退）。
set -eu

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

if command -v pacman >/dev/null 2>&1; then
  echo "==> 检测到 Arch Linux，使用 pacman 安装依赖"

  # 等待/处理 pacman 数据库锁（Omarchy 等可能有后台更新）
  i=0
  while [ -e /var/lib/pacman/db.lck ] && [ "$i" -lt 30 ]; do
    echo "    pacman 数据库被锁，等待中... ($((i*2))s)"
    sleep 2
    i=$((i+1))
  done
  if [ -e /var/lib/pacman/db.lck ]; then
    if pgrep -x pacman >/dev/null 2>&1; then
      echo "错误：有 pacman 正在运行，请等它结束后重试。" >&2
    else
      echo "错误：存在残留锁 /var/lib/pacman/db.lck。" >&2
      echo "      确认没有 pacman 在跑后执行：sudo rm -f /var/lib/pacman/db.lck" >&2
    fi
    exit 1
  fi

  # 容器里 keyring 可能过期
  $SUDO pacman -Sy --noconfirm archlinux-keyring || true

  # Arch 包名（systemd-libs 提供 libsystemd；SELinux 官方仓库没有，可选）
  ARCH_PKGS="base-devel git autoconf automake texinfo pkgconf zstd
    gnutls libxml2 jansson gmp gtk3 harfbuzz ncurses zlib
    libjpeg-turbo libpng giflib libtiff librsvg libxpm
    libotf m17n-lib systemd-libs dbus sqlite libffi nettle p11-kit
    libidn2 libunistring acl gpm libgccjit"

  # 只安装仓库中确实存在的包
  pkgs=""
  for p in $ARCH_PKGS; do
    if pacman -Si "$p" >/dev/null 2>&1; then
      pkgs="$pkgs $p"
    else
      echo "    跳过仓库中不存在的包：$p"
    fi
  done
  # shellcheck disable=SC2086
  $SUDO pacman -S --needed --noconfirm $pkgs

elif command -v apt-get >/dev/null 2>&1; then
  echo "==> 检测到 Debian/Ubuntu，使用 apt 安装依赖"
  # 默认源不可用时切清华镜像
  if ! $SUDO apt-get update -qq; then
    echo "==> 默认 apt 源不可用，切换到清华镜像"
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
      [ -f "$f" ] || continue
      $SUDO sed -i \
        -e 's|https\?://archive.ubuntu.com/ubuntu|https://mirrors.tuna.tsinghua.edu.cn/ubuntu|g' \
        -e 's|https\?://security.ubuntu.com/ubuntu|https://mirrors.tuna.tsinghua.edu.cn/ubuntu|g' \
        -e 's|https\?://ports.ubuntu.com/ubuntu-ports|https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports|g' \
        -e 's|https\?://deb.debian.org/debian|https://mirrors.tuna.tsinghua.edu.cn/debian|g' \
        -e 's|https\?://security.debian.org/debian-security|https://mirrors.tuna.tsinghua.edu.cn/debian-security|g' \
        "$f" 2>/dev/null || true
    done
    $SUDO apt-get update -qq
  fi

  $SUDO apt-get install -y --no-install-recommends software-properties-common >/dev/null 2>&1 || true
  $SUDO add-apt-repository -y universe >/dev/null 2>&1 || true

  # 运行时/开发包（不存在的会被自动过滤，如 libnettle-dev 实为 nettle-dev）
  DEB_PKGS="build-essential git autoconf automake texinfo pkg-config zstd curl ca-certificates
    libgnutls28-dev libxml2-dev libjansson-dev libgmp-dev
    libgtk-3-dev libharfbuzz-dev libncurses-dev zlib1g-dev
    libjpeg-dev libpng-dev libgif-dev libtiff-dev librsvg2-dev libxpm-dev
    libotf-dev libm17n-dev libsystemd-dev libdbus-1-dev libsqlite3-dev
    libffi-dev nettle-dev libp11-kit-dev libidn2-dev libunistring-dev
    libacl1-dev libselinux1-dev libgpm-dev"
  pkgs=""
  for p in $DEB_PKGS; do
    if apt-cache show "$p" >/dev/null 2>&1; then
      pkgs="$pkgs $p"
    else
      echo "    跳过仓库中不存在的包：$p"
    fi
  done
  # shellcheck disable=SC2086
  $SUDO apt-get install -y --no-install-recommends $pkgs

  # libgccjit 版本随发行版而异，逐个尝试（仅 -dev 包才有 -lgccjit）
  installed=no
  for v in 15 14 13 12 11 10; do
    if $SUDO apt-get install -y "libgccjit-${v}-dev"; then
      echo "已安装 libgccjit-${v}-dev"
      installed=yes
      break
    fi
  done
  [ "$installed" = yes ] || echo "警告：未找到 libgccjit-dev，构建时将自动关闭原生编译"

else
  echo "未识别的包管理器。请手动安装构建依赖（见 README 的构建说明）。" >&2
  exit 1
fi

echo "==> 依赖安装完成（若缺 libgccjit，构建会退回无原生编译）"
