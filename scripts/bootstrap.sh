#!/usr/bin/env bash
# 一条命令把环境装起来（Ubuntu 22.04 + ROS 2 Humble）。
#
#   ./scripts/bootstrap.sh --check     # 只体检，不改系统（默认）
#   ./scripts/bootstrap.sh --base      # 装 ROS 2 Humble 基础环境（需要 sudo）
#   ./scripts/bootstrap.sh --moveit    # 装 MoveIt 2（默认走 apt，快）
#   ./scripts/bootstrap.sh --deps      # rosdep 装本项目依赖
#   ./scripts/bootstrap.sh --build     # colcon build
#   ./scripts/bootstrap.sh --verify    # 冒烟测试
#   ./scripts/bootstrap.sh --all       # 以上全做
#
# 想固定用 2.5.9 源码版：`--moveit --from-source`（编译约 30~60 分钟，约 10 GB 磁盘）
set +u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"

MODE="${1:---check}"
FROM_SOURCE=0
for a in "$@"; do [ "$a" = "--from-source" ] && FROM_SOURCE=1; done

say()  { printf "\n\033[1m== %s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
die()  { printf "  \033[31m✗\033[0m %s\n" "$*"; exit 1; }

need_sudo() { sudo -v 2>/dev/null || die "需要 sudo（$*）"; }

check_os() {
  say "操作系统"
  . /etc/os-release
  [ "$ID" = "ubuntu" ] || die "需要 Ubuntu，当前是 $ID"
  [ "$VERSION_ID" = "22.04" ] || die "需要 Ubuntu 22.04（Humble），当前 $VERSION_ID
   → 换机器 / 用 docker/Dockerfile / 装 22.04 虚拟机"
  ok "Ubuntu $VERSION_ID $(uname -m)"
}

check_ros() {
  say "ROS 2 Humble"
  if [ -f /opt/ros/humble/setup.bash ]; then
    ok "已安装：$(. /opt/ros/humble/setup.bash && printenv ROS_DISTRO)"
  else
    warn "未安装 → 运行 ./scripts/bootstrap.sh --base"
  fi
}

check_moveit() {
  say "MoveIt 2"
  local apt_v src_v
  apt_v=$(apt-cache policy ros-humble-moveit 2>/dev/null | awk '/候选|Candidate/{print $2}' | head -1)
  src_v=""
  if [ -f "$HOME/ws_moveit/install/setup.bash" ]; then
    src_v=$(source /opt/ros/humble/setup.bash 2>/dev/null; source "$HOME/ws_moveit/install/setup.bash" 2>/dev/null; \
            ros2 pkg xml moveit_core 2>/dev/null | grep -oP '(?<=<version>)[^<]+' | head -1)
  fi
  [ -n "$src_v" ] && ok "源码 overlay（~/ws_moveit）：$src_v"
  dpkg -l 2>/dev/null | grep -q "^ii  ros-humble-moveit-core" && \
    ok "apt 版：$(dpkg -l | awk '/ros-humble-moveit-core/{print $3; exit}')"
  [ -z "$src_v" ] && ! dpkg -l 2>/dev/null | grep -q "^ii  ros-humble-moveit-core" && {
    warn "未安装"
    [ -n "$apt_v" ] && echo "     apt 可装版本：$apt_v  →  ./scripts/bootstrap.sh --moveit"
  }
}

check_toolchain() {
  say "工具链"
  for t in colcon rosdep cmake g++ python3; do
    if command -v "$t" >/dev/null; then ok "$t"; else warn "缺 $t"; fi
  done
  python3 -c 'import sys; print("  python", sys.version.split()[0], "(需要 3.10)")'
}

check_build() {
  say "本仓库构建"
  if [ -f "$ROOT/install/setup.bash" ]; then ok "已构建：install/ 存在"; else warn "未构建 → ./scripts/bootstrap.sh --build"; fi
}

do_base() {
  need_sudo "安装 ROS 2 Humble"
  say "安装 ROS 2 Humble"
  sudo apt update
  sudo apt install -y software-properties-common curl gnupg lsb-release
  # 官方源（国内可换成 mirrors.ustc.edu.cn，见 docs/install.md）
  sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
    | sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null
  sudo apt update
  sudo apt install -y ros-humble-desktop ros-dev-tools \
    python3-colcon-common-extensions python3-rosdep
  say "初始化 rosdep"
  [ -f /etc/ros/rosdep/sources.list.d/20-default.list ] || sudo rosdep init
  rosdep update
  ok "完成（重新开一个终端或 source /opt/ros/humble/setup.bash）"
}

do_moveit() {
  say "安装 MoveIt 2"
  if [ "$FROM_SOURCE" = 1 ]; then
    need_sudo "安装 MoveIt 编译依赖"
    sudo apt install -y ros-humble-moveit-common python3-vcstool build-essential \
      libfcl-dev ros-humble-ruckig ros-humble-octomap ros-humble-moveit-msgs
    mkdir -p "$HOME/ws_moveit/src" && cd "$HOME/ws_moveit"
    [ -d src/moveit2 ] || git clone --depth 1 -b humble https://github.com/moveit/moveit2.git src/moveit2
    ( cd src/moveit2 && git submodule update --init --recursive )
    source /opt/ros/humble/setup.bash
    rosdep install -y --from-paths src --ignore-src --rosdistro humble
    colcon build --symlink-install --cmake-args -DBUILD_TESTING=OFF
    ok "源码版完成：source $HOME/ws_moveit/install/setup.bash"
  else
    need_sudo "安装 MoveIt 2"
    sudo apt install -y ros-humble-moveit
    ok "apt 版完成：$(dpkg -l | awk '/ros-humble-moveit-core/{print $3; exit}')"
  fi
}

ensure_rosdep() {
  if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ] && [ ! -d "$HOME/.ros/rosdep" ]; then
    say "rosdep 尚未初始化，先初始化（需要 sudo）"
    need_sudo "rosdep init"
    sudo rosdep init
  fi
  # update 失败（离线/镜像慢）不该阻断构建，只提示
  rosdep update 2>&1 | tail -2 || warn "rosdep update 失败（可稍后重试）"
}

do_deps() {
  say "本项目依赖（rosdep）"
  ensure_rosdep
  source /opt/ros/humble/setup.bash
  [ -f "$HOME/ws_moveit/install/setup.bash" ] && source "$HOME/ws_moveit/install/setup.bash"
  rosdep install -y --from-paths src --ignore-src --rosdistro humble \
    --skip-keys="moveit_core moveit_ros_planning moveit_planners_ompl moveit_kinematics"
  ok "完成"
}

do_build() {
  say "编译"
  source /opt/ros/humble/setup.bash
  [ -f "$HOME/ws_moveit/install/setup.bash" ] && source "$HOME/ws_moveit/install/setup.bash"
  [ -n "$ROS_DISTRO" ] || die "ROS 2 没装好"
  colcon build --symlink-install
  ok "完成：source $ROOT/install/setup.bash"
}

case "$MODE" in
  --check)
    check_os; check_ros; check_moveit; check_toolchain; check_build
    say "下一步"
    echo "  缺基础环境 → ./scripts/bootstrap.sh --base"
    echo "  缺 MoveIt   → ./scripts/bootstrap.sh --moveit"
    echo "  准备编译    → ./scripts/bootstrap.sh --deps && ./scripts/bootstrap.sh --build"
    echo "  验证        → ./scripts/bootstrap.sh --verify"
    ;;
  --base)   check_os; do_base ;;
  --moveit) check_os; do_moveit ;;
  --deps)   do_deps ;;
  --build)  do_build ;;
  --verify) bash "$ROOT/scripts/verify_install.sh" ;;
  --all)    check_os; do_base; do_moveit; do_deps; do_build; bash "$ROOT/scripts/verify_install.sh" ;;
  *)        die "未知参数 $MODE（见脚本头部用法）" ;;
esac
