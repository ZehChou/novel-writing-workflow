#!/bin/bash
# 快照脚本：备份记忆层（知识库/摘要/canon/大纲 + 工作流）
# 用法: bash scripts/snapshot.sh <章号>

CHAPTER=$(printf "%02d" $((10#$1)))
SNAP=追踪/snapshots/ch-$CHAPTER

if [ -d "$SNAP" ]; then
  echo "快照目录已存在: $SNAP，跳过"
  exit 0
fi

mkdir -p "$SNAP"
cp -r 知识库 "$SNAP/"
cp -r 正文/摘要 "$SNAP/"
cp -r 大纲 "$SNAP/"
cp -r 追踪/canon "$SNAP/"
cp 工作流.md "$SNAP/" 2>/dev/null

cat > "$SNAP/snapshot-meta.md" <<EOF
# Snapshot ch-$CHAPTER
- 时间：$(date -Iseconds)
- 备注：
EOF

echo "快照已创建: $SNAP"