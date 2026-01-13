#!/usr/bin/env bash
# 启用严格模式： errexit、nounset、pipefail
set -o errexit -o nounset -o pipefail

# 初始化基础镜像，提取镜像ID
img="$(./bocker init ~/base-image | awk '{print $2}')"
# 检查镜像列表中是否存在该镜像（静默匹配）
./bocker images | grep -qw "$img"
# 验证上一步grep命令执行成功（退出码为0）
[[ "$?" == 0 ]]

# 运行容器检查wget是否安装
./bocker run "$img" which wget
# 提取执行该命令的容器ID
ps="$(./bocker ps | grep 'which wget' | awk '{print $1}')"
# 获取容器日志
logs="$(./bocker logs "$ps")"
# 删除该容器
./bocker rm "$ps"
# 验证日志显示wget未安装
[[ "$logs" == "which: no wget in"* ]]

# 运行容器安装wget
./bocker run "$img" yum install -y wget
# 提取执行安装命令的容器ID
ps="$(./bocker ps | grep 'yum install -y wget' | awk '{print $1}')"
# 将容器修改提交到原镜像
./bocker commit "$ps" "$img"

# 再次运行容器检查wget是否安装
./bocker run "$img" which wget
# 提取执行该命令的容器ID
ps="$(./bocker ps | grep 'which wget' | awk '{print $1}')"
# 获取容器日志
logs="$(./bocker logs "$ps")"
# 验证日志显示wget已安装（路径为/usr/bin/wget）
[[ "$logs" == '/usr/bin/wget' ]]
