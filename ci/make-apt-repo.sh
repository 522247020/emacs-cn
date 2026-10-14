#!/bin/sh
# 由 .deb 生成可直接托管的 apt 仓库（GitHub Pages / 任意静态服务器）。
#
# 用法：ci/make-apt-repo.sh <deb-dir> <out-root>
#   deb-dir   存放 .deb 的目录，文件名形如：
#               emacs-cn-debian_<ver>_<arch>.deb
#               emacs-cn-wayland-debian_<ver>_<arch>.deb
#               emacs-cn-ubuntu_...
#   out-root  输出目录，生成：
#               <out-root>/debian/...
#               <out-root>/ubuntu/...
#               <out-root>/index.html
#
# 依赖：dpkg-dev（dpkg-scanpackages）、apt-utils（apt-ftparchive）
# 可选：环境变量 APT_GPG_KEY = 私钥文本时，对 Release 签名（生成 InRelease/Release.gpg）
set -eu

DEBDIR=${1:?用法: make-apt-repo.sh <deb-dir> <out-root>}
OUT=${2:?}
SUITE=stable
COMPONENT=main

have() { command -v "$1" >/dev/null 2>&1; }

build_one() {
  distro=$1
  root="$OUT/$distro"
  pool="$root/pool/$COMPONENT"
  mkdir -p "$pool"

  n=0
  for f in "$DEBDIR"/*-"$distro"_*.deb; do
    [ -f "$f" ] || continue
    cp "$f" "$pool/"
    n=$((n + 1))
  done
  if [ "$n" -eq 0 ]; then
    echo "跳过 $distro（没有 .deb）"
    return 0
  fi
  echo "==> $distro：$n 个 .deb"

  if ! have dpkg-scanpackages || ! have apt-ftparchive; then
    echo "警告：缺少 dpkg-scanpackages / apt-ftparchive，跳过 $distro"
    return 0
  fi

  tmp=$(mktemp -d)
  # 生成含全部架构的 Packages，再按 Architecture 拆分
  ( cd "$root" && dpkg-scanpackages "pool/$COMPONENT" /dev/null ) > "$tmp/all"
  awk -v RS='' -v ORS='\n\n' -v dir="$tmp" '
    {
      arch = ""
      n = split($0, L, "\n")
      for (i = 1; i <= n; i++)
        if (L[i] ~ /^Architecture: /) { arch = substr(L[i], 15); break }
      if (arch != "") print $0 >> (dir "/" arch)
    }
  ' "$tmp/all"

  arches=""
  for f in "$tmp"/*; do
    [ -f "$f" ] || continue
    a=$(basename "$f")
    [ "$a" = all ] && continue
    d="$root/dists/$SUITE/$COMPONENT/binary-$a"
    mkdir -p "$d"
    cp "$f" "$d/Packages"
    gzip -9 -c "$d/Packages" > "$d/Packages.gz"
    arches="$arches $a"
  done
  rm -rf "$tmp"

  # Release（apt-ftparchive 计算校验和）
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="emacs-cn" \
    -o APT::FTPArchive::Release::Label="emacs-cn" \
    -o APT::FTPArchive::Release::Suite="$SUITE" \
    -o APT::FTPArchive::Release::Codename="$SUITE" \
    -o APT::FTPArchive::Release::Architectures="$arches" \
    -o APT::FTPArchive::Release::Components="$COMPONENT" \
    -o APT::FTPArchive::Release::Description="Chinese-localized GNU Emacs" \
    release "$root/dists/$SUITE" > "$root/dists/$SUITE/Release"

  # 可选签名
  if [ -n "${APT_GPG_KEY:-}" ] && have gpg; then
    printf '%s' "$APT_GPG_KEY" | gpg --batch --import 2>/dev/null || true
    gpg --batch --yes --armor --detach-sign \
      -o "$root/dists/$SUITE/Release.gpg" "$root/dists/$SUITE/Release" 2>/dev/null || true
    gpg --batch --yes --clearsign \
      -o "$root/dists/$SUITE/InRelease" "$root/dists/$SUITE/Release" 2>/dev/null || true
    gpg --armor --export > "$OUT/emacs-cn.gpg" 2>/dev/null || true
  fi
}

build_one debian
build_one ubuntu

: > "$OUT/.nojekyll"

cat > "$OUT/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>emacs-cn apt 仓库</title>
<h1>emacs-cn — 中文版 GNU Emacs</h1>
<h2>Debian / Raspberry Pi OS</h2>
<pre>
echo "deb [trusted=yes] https://522247020.github.io/emacs-cn/debian stable main" | sudo tee /etc/apt/sources.list.d/emacs-cn.list
sudo apt update
sudo apt install emacs-cn            # X11
sudo apt install emacs-cn-wayland    # Wayland (pgtk)
</pre>
<h2>Ubuntu</h2>
<pre>
echo "deb [trusted=yes] https://522247020.github.io/emacs-cn/ubuntu stable main" | sudo tee /etc/apt/sources.list.d/emacs-cn.list
sudo apt update
sudo apt install emacs-cn
sudo apt install emacs-cn-wayland
</pre>
<p>把 <code>https://522247020.github.io/emacs-cn/</code> 换成你实际部署的地址即可。</p>
HTML

echo "==> apt 仓库已生成于 $OUT"
