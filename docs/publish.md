# 私有仓库 → 公开镜像（作品集）

## 架构

```
私有  heyxz/rosim_ws        全量：代码 + 对话记忆 + 跨机部署 + 桥接配置
         │  ./scripts/publish_public.sh（导出 → 过滤 → 脱敏 → 快照提交）
         ▼
公开  heyxz/smartweld       作品集：只有代码 / 文档 / 脚本 / 机器人模型
```

公开仓库的提交是**快照链**（`sync from private@<sha>`），不是私有历史的复制——
所以历史里的记忆内容不会漏出去。

## 用法

```bash
./scripts/publish_public.sh --dry-run   # 只导出到 .scratch/publish/src，不推送
./scripts/publish_public.sh             # 导出 → 提交 → 推送到公开仓库
```

首次使用前要先有公开空仓库（**保持空白**，不要勾 README/gitignore/license）：

```bash
# 只需一次（网页操作）：https://github.com/new → 名字 smartweld → Public
```

## 排除清单（`scripts/publish_public.sh` 里的 `EXCLUDE`）

| 路径 | 原因 |
| --- | --- |
| `docs/memory.md` | 对话记忆：内网信息、业务讨论 |
| `AGENTS.local.md` | 记忆软链 |
| `docs/tasks.md` | 内部任务队列 |
| `docs/laptop_env.md` | 本机路径与部署细节 |
| `dsh-bridge/` | 桥接服务：含 `.env` 密钥、会话存储 |
| `.scratch/` | 临时产物 |

## 脱敏规则（`SCRUB`）

```
/home/user          → /home/user
laptop             → laptop
<hw-id>       → <hw-id>
192.168.31.x      → <lan-ip>
```

发布前脚本会打印"被修改的文件"；`--dry-run` 后可以人工再扫一遍：

```bash
grep -rn "192\.168\.\|/home/user" .scratch/publish/src | head
```

## 已知取舍

- 公开仓库没有真实开发历史（每次都是快照），但能看到持续迭代的痕迹
- 机器人网格（约 55 MB STL）一起公开，占仓库大部分体积
- 想彻底隐藏某个文件时，加进 `EXCLUDE` 再发布即可（已发布过的历史快照
  里还有旧内容，需要的话得重写公开仓库历史）
