#!/usr/bin/env bash
# 启用严格模式： errexit、nounset、pipefail
set -o errexit -o nounset -o pipefail

# 拉取centos 7镜像，屏蔽错误输出，提取镜像ID
centos_img="$(./bocker pull centos 7 2> /dev/null | awk '{print $2}')"
# 运行centos容器查看系统版本
./bocker run "$centos_img" cat /etc/redhat-release
# 提取执行该命令的容器ID
ps="$(./bocker ps | grep 'cat /etc/redhat-release' | awk '{print $1}')"
# 获取容器日志
logs="$(./bocker logs "$ps")"
# 删除该容器
./bocker rm "$ps"
# 验证日志显示为CentOS 7版本
[[ "$logs" == "CentOS Linux release 7"* ]]

# 拉取ubuntu 14.04镜像，屏蔽错误输出，提取镜像ID
ubuntu_img="$(./bocker pull ubuntu 14.04 2> /dev/null | awk '{print $2}')"
# 运行ubuntu容器查看lsb-release最后一行
./bocker run "$ubuntu_img" tail -n1 /etc/lsb-release
# 提取执行该命令的容器ID
ps="$(./bocker ps | grep 'tail -n1 /etc/lsb-release' | awk '{print $1}')"
# 获取容器日志
logs="$(./bocker logs "$ps")"
# 删除该容器
./bocker rm "$ps"
# 验证日志包含Ubuntu 14.04
[[ "$logs" == *"Ubuntu 14.04"* ]]
