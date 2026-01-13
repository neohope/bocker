#!/usr/bin/env bash
# 启用严格模式： errexit(非零退出则脚本退出)、nounset(未定义变量报错)、pipefail(管道任一命令失败则整体失败)
set -o errexit -o nounset -o pipefail

# 初始化基础镜像，提取返回的镜像ID
img="$(./bocker init ~/base-image | awk '{print $2}')"
# 检查镜像列表中是否存在该镜像（静默匹配）
./bocker images | grep -qw "$img"
# 验证上一步grep命令执行成功（退出码为0）
[[ "$?" == 0 ]]

# ▼ ▼ ▼ 存在竞态条件风险的代码块 ▼ ▼ ▼
# 后台运行容器，执行sleep 5后查看进程
./bocker run "$img" "sleep 5 && ps aux" &
# 休眠2秒，等待容器进程启动（此处休眠时间固定，易触发竞态）
sleep 2
# 提取包含sleep 5的容器ID
ps="$(./bocker ps | grep 'sleep 5' | awk '{print $1}')"
# 在容器内执行ps aux，统计输出行数
exec="$(./bocker exec "$ps" ps aux | wc -l)"
# 验证执行结果行数为4
[[ "$exec" == "4" ]]
# 休眠3秒，等待容器内sleep 5执行完成
sleep 3
# ▲ ▲ ▲ 竞态条件风险代码块结束 ▲ ▲ ▲

# 运行容器执行ps aux命令
./bocker run "$img" ps aux
# 提取包含ps aux的容器ID
ps="$(./bocker ps | grep 'ps aux' | awk '{print $1}')"
# 尝试在容器内执行ps aux（容器已退出，执行失败），true确保脚本不中断
exec="$(./bocker exec "$ps" ps aux)" || true
# 验证执行失败的提示信息（容器存在但未运行）
[[ "$exec" == "Container '$ps' exists but is not running" ]]

# 尝试对不存在的容器foo执行exec，true确保脚本不中断
exec="$(./bocker exec foo ps aux)" || true
# 验证执行失败的提示信息（容器不存在）
[[ "$exec" == "No container named 'foo' exists" ]]
