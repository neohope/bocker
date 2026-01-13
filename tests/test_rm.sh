#!/usr/bin/env bash
# 启用严格模式： errexit、nounset、pipefail
set -o errexit -o nounset -o pipefail

# 初始化基础镜像，提取镜像ID
img="$(./bocker init ~/base-image | awk '{print $2}')"
# 定义随机echo命令
cmd="echo $RANDOM"
# 运行容器执行上述随机命令
./bocker run "$img" "$cmd"
# 提取执行该命令的容器ID
ps="$(./bocker ps | grep "$cmd" | awk '{print $1}')"

# 验证镜像列表中该镜像数量为1
[[ "$(./bocker images | grep -c "$img")" == 1 ]]
# 验证容器列表中该命令对应的容器数量为1
[[ "$(./bocker ps | grep -c "$cmd")" == 1 ]]

# 删除该镜像
./bocker rm "$img"
# 删除该容器
./bocker rm "$ps"

# 验证镜像列表中该镜像已被删除（数量为0）
[[ "$(./bocker images | grep -c "$img")" == 0 ]]
# 验证容器列表中该命令对应的容器已被删除（数量为0）
[[ "$(./bocker ps | grep -c "$cmd")" == 0 ]]
