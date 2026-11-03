#!/usr/bin/env bash
# RL 策略推理节点：提供 /rl_plan 服务（供 C++ 的 RlRemotePlanner 调用）
set -e
RL_A_DIR="${RL_A_DIR:-/home/user/rosim_ws/rl_a}"
LIBS="${RL_PYLIBS:-/home/user/rosim_ws/.pylibs}"
source /opt/ros/humble/setup.bash
source /home/user/ws_moveit/install/setup.bash
[ -f /home/user/rosim_ws/install/setup.bash ] && source /home/user/rosim_ws/install/setup.bash
export RL_PLAN_LOG="${RL_PLAN_LOG:-/home/user/rosim_ws/.scratch/rl_requests.jsonl}"
export ROSIM_RL_MAX_DELTA="${ROSIM_RL_MAX_DELTA:-1.5}"
export RL_OUT_DIR="${RL_OUT_DIR:-$RL_A_DIR/out_bank_scene}"
export RL_A_DIR
export ROS_LOG_DIR="${ROS_LOG_DIR:-/home/user/rosim_ws/.scratch/roslog}"
export ROS_HOME="${ROS_HOME:-/home/user/rosim_ws/.scratch/roshome}"
export PYTHONPATH="$LIBS:$RL_A_DIR:${PYTHONPATH}"
export MPLCONFIGDIR="$LIBS/../.mpl"
exec python3 /home/user/rosim_ws/scripts/rl_plan_node.py "$@"
