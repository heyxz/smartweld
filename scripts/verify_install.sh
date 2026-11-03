#!/usr/bin/env bash
# 安装后冒烟测试：起服务 → 等 8765 → 调一次规划 → 关掉。
# 退出码 0 = 环境可用。
set +u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
source /opt/ros/humble/setup.bash
[ -f "$ROOT/install/setup.bash" ] && source "$ROOT/install/setup.bash"
export ROS_LOG_DIR="${ROS_LOG_DIR:-$ROOT/.scratch/roslog}"
export ROS_HOME="${ROS_HOME:-$ROOT/.scratch/roshome}"
mkdir -p "$ROS_LOG_DIR" "$ROS_HOME"

fail() { echo "❌ $*"; exit 1; }

echo "=== 1/4 包是否都在 ==="
ros2 pkg prefix rosim_planning >/dev/null 2>&1 || fail "找不到 rosim_planning（先 colcon build）"
ros2 pkg prefix moveit_core >/dev/null 2>&1 || fail "找不到 moveit_core（先装 MoveIt）"
echo "  ok"

echo "=== 2/4 起服务（最长 60 s）==="
ros2 launch rosim_server server.launch.py > "$ROOT/.scratch/verify_server.log" 2>&1 &
SRV=$!
trap 'kill -INT $SRV 2>/dev/null; sleep 2; kill -9 $SRV 2>/dev/null' EXIT
for i in $(seq 60); do
  sleep 1
  if curl -s -o /dev/null -m 1 http://127.0.0.1:8765/; then break; fi
  [ $i -eq 60 ] && fail "8765 起不来，日志见 .scratch/verify_server.log"
done
echo "  ok（8765 已监听）"

echo "=== 3/4 规划一次（IK + OMPL）==="
OUT=$(timeout 60 ros2 service call /rosim_planning/plan_joint \
        rosim_interfaces/srv/PlanJoint "{goal: [0.2, 0.1, -0.3, 0.1, 0.15, 0.25]}" 2>&1)
echo "$OUT" | grep -q "success=True" || fail "plan_joint 失败：$(echo "$OUT" | tail -3)"
echo "  ok"

echo "=== 4/4 关节状态 ==="
timeout 15 ros2 topic echo /joint_states --once 2>/dev/null | grep -q "name:" || fail "没有 /joint_states"
echo "  ok"

echo
echo "✅ 环境可用：服务能起、规划能解、状态在发。"
echo "   打开 http://localhost:8765/ 看界面。"
