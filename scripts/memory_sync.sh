#!/usr/bin/env bash
# 把跨机共享记忆（docs/memory.md）与远端对齐：先拉取，再提交本机改动，再推送。
#
#   ./scripts/memory_sync.sh
#
# 关键点：**即使本机没有改动也要拉取**——否则被动的那台永远看不到对方写的记忆
# （早期版本在校验无改动时直接 exit，导致两台各自累积、互不可见）。
set +u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
F="docs/memory.md"
[ -f "$F" ] || { echo "缺少 $F"; exit 1; }

pull() {
  if git pull --rebase --autostash -q 2>/dev/null; then return 0; fi

  # 记忆文件是**滚动窗口**（桥每次都会整块重写），冲突时取远端版本即可，
  # 没必要人工介入。之前没处理，导致两台同时提交时仓库卡在 rebase 状态、
  # 记忆区块里残留 <<<<<<< 标记（2026-11-03 实际踩过）。
  local conflicted
  conflicted=$(git diff --name-only --diff-filter=U 2>/dev/null | tr '\n' ' ')
  if [ "$conflicted" = "docs/memory.md " ] || [ "$conflicted" = "docs/memory.md" ]; then
    if git checkout --ours -- docs/memory.md 2>/dev/null; then
      git add docs/memory.md
      if GIT_EDITOR=true git rebase --continue >/dev/null 2>&1; then
        echo "（记忆冲突：已取远端版本）"
        return 0
      fi
    fi
  fi

  git rebase --abort 2>/dev/null
  echo "⚠ 拉取失败（非记忆文件冲突，或远端不可达），下轮重试"
  return 1
}

# 1) 先拉：让本机看到对方写入的记忆
PULLED=0
pull && PULLED=1

# 2) 本机若产生过记忆，提交
git add "$F" 2>/dev/null
if git diff --cached --quiet -- "$F"; then
  [ "$PULLED" = 1 ] && echo "记忆已是最新（拉取完成）" || echo "记忆无变化"
  exit 0
fi
git commit -q -m "memory: $(date '+%F %H:%M')" -- "$F" || { echo "提交失败"; exit 1; }

# 3) 提交后再拉一次（远端可能刚被别人推进），然后推送
pull >/dev/null 2>&1
if git push -q 2>/dev/null; then
  echo "✅ 记忆已推送"
else
  echo "⚠ 推送失败（远端不可达或需要先 rebase），下轮重试"
fi
