#!/bin/sh
# 在 Gitea 上幂等创建 tag + Release，然后上传产物附件。
#
# 环境变量：GITHUB_SERVER_URL GITHUB_REPOSITORY GITHUB_REF GITHUB_REF_NAME
#           GITHUB_SHA TOKEN
# 用法：ci/gitea-release.sh <file>...
set -eu

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
API="${GITHUB_SERVER_URL}/api/v1/repos/${GITHUB_REPOSITORY}"
AUTH="Authorization: token ${TOKEN}"

case "${GITHUB_REF:-}" in
  refs/tags/*) TAG="${GITHUB_REF_NAME}" ;;
  refs/heads/main)
    [ -f VERSION ] || { echo "缺少 VERSION 文件"; exit 1; }
    TAG="v$(cat VERSION)" ;;
  *) echo "非 main/tag，跳过发布"; exit 0 ;;
esac
echo "== TAG=$TAG =="

# 1) 创建 tag（已存在也继续）
printf '{"tag_name":"%s","target":"%s"}' "$TAG" "${GITHUB_SHA}" > /tmp/tag.json
code=$(curl -s -o /tmp/tag.out -w '%{http_code}' -X POST "$API/tags" \
  -H "$AUTH" -H 'Content-Type: application/json' --data @/tmp/tag.json)
echo "tag HTTP $code"; cat /tmp/tag.out; echo

# 2) 创建 Release（已存在也继续）
printf '{"tag_name":"%s","name":"%s","target_commitish":"%s"}' \
  "$TAG" "$TAG" "${GITHUB_SHA}" > /tmp/rel.json
code=$(curl -s -o /tmp/rel.out -w '%{http_code}' -X POST "$API/releases" \
  -H "$AUTH" -H 'Content-Type: application/json' --data @/tmp/rel.json)
echo "release HTTP $code"; cat /tmp/rel.out; echo

# 3) 上传附件
exec "$SELF_DIR/gitea-upload.sh" "$@"
