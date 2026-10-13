#!/bin/sh
# 从预编译产物安装中文版 Emacs（安装到 /opt/emacs-cn）。
#
# 用法：
#   sh install.sh [emacs-cn-linux-x86_64.tar.zst]
#
# 说明：
#   * 产物把前缀 /opt/emacs-cn 编译进了 Emacs，必须解包到 /。
#   * 需要 root（或 sudo），以及 zstd。
#   * 新设备需与构建环境（Ubuntu 系）glibc/依赖库兼容，否则请自行编译。
set -eu

TARBALL=${1:-emacs-cn-linux-x86_64.tar.zst}
[ -f "$TARBALL" ] || { echo "错误：找不到 $TARBALL" >&2; exit 1; }

if ! command -v zstd >/dev/null 2>&1; then
  echo "错误：缺少 zstd。请先安装：" >&2
  echo "  Debian/Ubuntu: sudo apt install zstd" >&2
  echo "  Fedora:        sudo dnf install zstd" >&2
  echo "  Arch:          sudo pacman -S zstd" >&2
  exit 1
fi

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "==> 解包到 / （安装到 /opt/emacs-cn）"
$SUDO tar --zstd -xf "$TARBALL" -C /

echo "==> 创建 emacs-cn 命令"
if [ -w /usr/local/bin ]; then
  ln -sf /opt/emacs-cn/bin/emacs /usr/local/bin/emacs-cn
else
  $SUDO ln -sf /opt/emacs-cn/bin/emacs /usr/local/bin/emacs-cn
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

echo "==> 检查动态库依赖"
if ldd /opt/emacs-cn/bin/emacs 2>/dev/null | grep -q "not found"; then
  echo "警告：以下依赖库缺失，需要安装对应软件包："
  ldd /opt/emacs-cn/bin/emacs | grep "not found"
else
  echo "依赖库齐全。"
fi

echo
echo "安装完成："
echo "  可执行文件: /opt/emacs-cn/bin/emacs"
echo "  命令:       emacs-cn        （终端用 emacs-cn -nw）"
/opt/emacs-cn/bin/emacs --version | head -1 || true
