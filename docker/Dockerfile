# smartweld 运行/开发容器
#
#   docker build -f docker/Dockerfile -t smartweld .
#   docker run --rm -it --net=host -v "$PWD":/workspace smartweld
#   # 容器内：
#   #   source /opt/ros/humble/setup.bash
#   #   rosdep install -y --from-paths src --ignore-src
#   #   colcon build --symlink-install
#   #   bash scripts/verify_install.sh
#
# 基于官方 ros:humble（Ubuntu 22.04）。MoveIt 走 apt（2.5.10），镜像约 3~4 GB。
#
# 状态：**未在开发机验证**（那台没有 docker）。这条路径的等价版本已在第二台机器上
#      实测通过：apt MoveIt 2.5.10 → colcon build（7 包，4 分 52 秒）→ 冒烟 4/4。
FROM ros:humble

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-humble-desktop \
        ros-humble-moveit \
        python3-colcon-common-extensions \
        python3-rosdep \
        build-essential \
        cmake \
        git \
        libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init 2>/dev/null || true

WORKDIR /workspace
CMD ["bash"]
