#!/bin/sh
# 把中文手册译文（l10n/manual-zh/<手册名>/）套用到 src/doc/<手册名>/，
# 使 make / make install 构建出的 Info 手册为中文。
set -eu

HERE=$(cd "$(dirname "$0")/.." && pwd)
BASE="$HERE/l10n/manual-zh"

[ -d "$BASE" ] || { echo "错误：找不到中文手册目录 $BASE" >&2; exit 1; }

total=0
for d in "$BASE"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  dst="$HERE/src/doc/$name"
  if [ ! -d "$dst" ]; then
    echo "跳过 $name（src/doc/$name 不存在）"
    continue
  fi
  n=0
  for f in "$d"*.texi; do
    [ -f "$f" ] || continue
    cp "$f" "$dst/$(basename "$f")"
    n=$((n+1))
  done
  echo "已套用 $name: $n 个文件 -> $dst"
  total=$((total+n))
done
echo "共套用 $total 个中文手册文件"
