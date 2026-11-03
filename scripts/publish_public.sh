#!/usr/bin/env bash
# 把私有仓库的代码发布到公开镜像仓库（作品集用）。
#
#   ./scripts/publish_public.sh --dry-run     # 只看会发布什么，不推送
#   ./scripts/publish_public.sh               # 导出 → 脱敏 → 提交 → 推送
#
# 设计：
#   1. 用 `git archive` 导出**当前提交**（不带历史，天然不会带出旧记忆）
#   2. 删除排除清单（记忆、任务队列、跨机配置、桥接目录等）
#   3. 对文本文件做敏感串替换（内网 IP / 主机名 / 硬件编号 / 家目录）
#   4. 覆盖到公开仓库的工作区 → 提交一条 "sync from private@<sha>" → 推送
#      → 公开仓库的历史是**干净的快照链**，不是私有历史的重写
set +u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
PUBLIC_REMOTE="${PUBLIC_REMOTE:-git@github.com:heyxz/smartweld.git}"
WORK="${PUBLIC_WORK:-$ROOT/.scratch/publish}"
DRY=0
[ "$1" = "--dry-run" ] && DRY=1

# 1) 排除清单（相对仓库根）
EXCLUDE=(
  docs/memory.md            # 对话记忆（含内网信息、业务讨论）
  AGENTS.local.md           # 记忆软链
  docs/tasks.md             # 内部任务队列
  docs/laptop_env.md        # 含本机路径与内网信息（按需放开）
  dsh-bridge/               # 桥接：含 .env / 会话存储
  .scratch/                 # 临时产物
)
# 2) 脱敏规则（sed 表达式）
SCRUB=(
  's#/home/user#/home/user#g'
  's#laptop#laptop#g'
  's#<hw-id>#<hw-id>#g'
  's#192\.168\.31\.[0-9]\+#<lan-ip>#g'
  's#192\.168\.[0-9]\+\.[0-9]\+#<lan-ip>#g'
)

SHA=$(git rev-parse --short HEAD)
echo "私有仓库当前提交: $SHA"

rm -rf "$WORK"; mkdir -p "$WORK/src"
git archive HEAD | tar -x -C "$WORK/src" || { echo "导出失败"; exit 1; }

echo "=== 排除 ==="
for p in "${EXCLUDE[@]}"; do
  if [ -e "$WORK/src/$p" ]; then rm -rf "$WORK/src/$p"; echo "  - $p"; else echo "  (无) $p"; fi
done

echo "=== 脱敏 ==="
changed=0
while IFS= read -r f; do
  case "$f" in *.png|*.jpg|*.jpeg|*.npz|*.onnx|*.pt|*.stl|*.step|*.dae) continue;; esac
  before=$(md5sum "$f" | cut -d' ' -f1)
  for rule in "${SCRUB[@]}"; do sed -i "$rule" "$f"; done
  after=$(md5sum "$f" | cut -d' ' -f1)
  [ "$before" != "$after" ] && { echo "  ~ ${f#$WORK/src/}"; changed=$((changed+1)); }
done < <(find "$WORK/src" -type f -size -2M)
echo "  共修改 $changed 个文件"

cat > "$WORK/src/PUBLIC_MIRROR.md" <<EOF
# 这是镜像仓库

本仓库是 \`rosim_ws\` 的**公开镜像**，用于展示代码与文档。

- 上游私有仓库包含完整的开发历史、对话记忆与跨机部署配置，不对外公开
- 本镜像每次发布都是**一次性快照**：提交信息形如 \`sync from private@<sha>\`
- 已排除：对话记忆、内部任务队列、桥接服务目录、跨机部署细节
- 已脱敏：内网 IP、主机名、硬件编号、绝对家目录路径

最近同步：private@$SHA
EOF

echo "=== 发布内容概览 ==="
echo "  文件数: $(find "$WORK/src" -type f | wc -l)"
echo "  体积:   $(du -sh "$WORK/src" | cut -f1)"
echo "  顶层:   $(ls "$WORK/src" | tr '\n' ' ')"

if [ "$DRY" = 1 ]; then
  echo
  echo "（dry-run：未推送。发布副本在 $WORK/src）"
  echo "  可先人工检查：ls $WORK/src ; grep -rn '<lan-ip>' $WORK/src | head"
  exit 0
fi

echo "=== 同步到公开仓库 ==="
if [ -d "$WORK/pub/.git" ]; then
  git -C "$WORK/pub" fetch -q origin && git -C "$WORK/pub" reset -q --hard origin/HEAD
else
  git clone -q "$PUBLIC_REMOTE" "$WORK/pub" || { echo "克隆公开仓库失败（远端是否已创建？）"; exit 1; }
fi
rsync -a --delete --exclude .git "$WORK/src/" "$WORK/pub/" || { echo "rsync 失败"; exit 1; }
git -C "$WORK/pub" add -A
if git -C "$WORK/pub" diff --cached --quiet; then
  echo "公开仓库无变化，跳过"
else
  git -C "$WORK/pub" commit -q -m "sync from private@$SHA"
  git -C "$WORK/pub" push -q origin HEAD 2>&1 | tail -2
  echo "✅ 已发布 private@$SHA"
fi
