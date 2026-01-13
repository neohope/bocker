#!/usr/bin/env bash
# 启用严格模式： errexit、nounset、pipefail
set -o errexit -o nounset -o pipefail

# 定义bocker run测试函数：参数1=镜像ID，参数2=执行命令，参数3=预期日志关键词
function bocker_run_test() {
	# 运行容器执行指定命令，屏蔽标准输出
	./bocker run "$1" "$2" > /dev/null
	# 提取执行该命令的容器ID
	ps="$(./bocker ps | grep "$2" | awk '{print $1}')"
	# 获取容器日志
	logs="$(./bocker logs "$ps")"
	# 检查日志是否包含预期关键词，包含则返回0（成功），否则返回1（失败）
	if [[ "$logs" == *"$3"* ]]; then
		echo 0
	else
		echo 1
	fi
}

# 初始化基础镜像，提取镜像ID
img="$(./bocker init ~/base-image | awk '{print $2}')"
# 检查镜像列表中是否存在该镜像（静默匹配）
./bocker images | grep -qw "$img"
# 验证上一步grep命令执行成功（退出码为0）
[[ "$?" == 0 ]]

# 测试echo foo命令，验证日志包含foo
[[ "$(bocker_run_test "$img" 'echo foo' 'foo')" == 0 ]]
# 测试uname命令，验证日志包含Linux
[[ "$(bocker_run_test "$img" 'uname' 'Linux')" == 0 ]]
# 测试查看进程stat，验证日志包含3 (cat)
[[ "$(bocker_run_test "$img" 'cat /proc/self/stat' '3 (cat)')" == 0 ]]
# 测试查看网卡，验证日志包含veth1_ps_
[[ "$(bocker_run_test "$img" 'ip addr' 'veth1_ps_')" == 0 ]]
# 测试ping 8.8.8.8，验证日志包含0% packet loss
[[ "$(bocker_run_test "$img" 'ping -c 1 8.8.8.8' '0% packet loss')" == 0 ]]
# 测试ping google.com，验证日志包含0% packet loss
[[ "$(bocker_run_test "$img" 'ping -c 1 google.com' '0% packet loss')" == 0 ]]
