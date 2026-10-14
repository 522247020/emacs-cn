#!/bin/sh
# 把构建产物作为附件上传到 Gitea 的 Release（幂等）。
#
# 环境变量（Gitea Actions 自动提供）：
#   GITHUB_SERVER_URL GITHUB_REPOSITORY GITHUB_REF GITHUB_REF_NAME TOKEN
# 用法：ci/gitea-upload.sh <file>...
#
# 只删除“与被上传文件同名”的旧附件，不会影响其它 job 上传的产物。
set -eu

API="${GITHUB_SERVER_URL}/api/v1/repos/${GITHUB_REPOSITORY}"
AUTH="Authorization: token ${TOKEN}"

case "${GITHUB_REF:-}" in
  refs/tags/*) TAG="${GITHUB_REF_NAME}" ;;
  *)           TAG="v$(cat VERSION)" ;;
esac

REL=$(curl -s -H "$AUTH" "$API/releases/tags/$TAG")
RID=$(printf '%s' "$REL" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2 || true)
if [ -z "${RID:-}" ]; then
  echo "未找到 Release $TAG（可能主构建尚未发布），跳过上传"
  exit 0
fi
echo "Release $TAG id=$RID"

for f in "$@"; do
  [ -f "$f" ] || { echo "跳过（不存在）: $f"; continue; }
  name=$(basename "$f")

  # 删除同名旧附件
  for aid in $(curl -s -H "$AUTH" "$API/releases/$RID/assets" \
               | grep -o '"id":[0-9]*' | cut -d: -f2); do
    aname=$(curl -s -H "$AUTH" "$API/releases/$RID/assets/$aid" \
            | grep -o '"name":"[^"]*"' | head -1 | sed 's/.*:"//;s/"$//')
    if [ "$aname" = "$name" ]; then
      curl -s -X DELETE -H "$AUTH" "$API/releases/$RID/assets/$aid" >/dev/null || true
    fi
  done

  code=$(curl -s -o /tmp/upload.out -w '%{http_code}' -X POST \
    "$API/releases/$RID/assets?name=$name" \
    -H "$AUTH" -F "attachment=@$f")
  echo "$name HTTP $code"
  [ "$code" = 201 ] || { echo "附件上传失败: $name"; cat /tmp/upload.out; exit 1; }
done
echo "已上传到 Release $TAG"
