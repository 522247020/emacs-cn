#!/bin/sh
# 把中文手册译文（l10n/manual-zh/）套用到 src/doc/emacs/，
# 这样 make / make install 构建出的 emacs.info 就是中文，C-h r 打开中文手册。
set -eu

HERE=$(cd "$(dirname "$0")/.." && pwd)
SRC="$HERE/l10n/manual-zh"
DST="$HERE/src/doc/emacs"

[ -d "$SRC" ] || { echo "错误：找不到中文手册目录 $SRC" >&2; exit 1; }
[ -d "$DST" ] || { echo "错误：找不到手册源码目录 $DST" >&2; exit 1; }

n=0
for f in "$SRC"/*.texi; do
  [ -f "$f" ] || continue
  cp "$f" "$DST/$(basename "$f")"
  n=$((n+1))
done
echo "已套用 $n 个中文手册文件到 $DST"
