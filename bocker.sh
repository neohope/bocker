#!/usr/bin/env bash
# 脚本执行模式：命令失败则脚本终止
set -o errexit
# 脚本执行模式：引用未定义变量则报错并终止
set -o nounset
# 脚本执行模式：管道中任一子命令失败则整个管道失败，脚本终止
set -o pipefail
# 通配符匹配模式：无匹配文件时返回空串（而非原通配符字符串）
shopt -s nullglob

# 定义bocker的核心工作目录（基于btrfs文件系统）
btrfs_path='/var/bocker'
# 定义容器使用的cgroup资源组（CPU、CPU统计、内存）
cgroups='cpu,cpuacct,memory'

# 处理命令行前缀为--的参数（如--cpu-share=1024）
# 若传入参数数量大于0，且参数以--开头，则循环解析
[[ $# -gt 0 ]] && while [ "${1:0:2}" == '--' ]; do
  # 截取--后的参数名（如--cpu-share=1024 → cpu-share=1024）
  OPTION=${1:2}
  # 若参数包含=，则拆分为变量名（BOCKER_前缀）和值；否则设值为x
  [[ $OPTION =~ = ]] && declare "BOCKER_${OPTION/=*/}=${OPTION/*=/}" || declare "BOCKER_${OPTION}=x"; 
  # 移除已解析的参数，处理下一个
  shift; 
done

# 检查btrfs子卷是否存在
# 参数：子卷名称；返回：0存在/1不存在
function bocker_check() {
	btrfs subvolume list "$btrfs_path" | grep -qw "$1" && echo 0 || echo 1
}

# 从指定目录创建镜像
# 使用方式：bocker init <directory>
function bocker_init() { #HELP Create an image from a directory:\nBOCKER init <directory>
	# 生成镜像唯一ID（前缀img_，随机数范围42002-42254）
	uuid="img_$(shuf -i 42002-42254 -n 1)"
	# 检查传入的目录是否存在
	if [[ -d "$1" ]]; then
		# 若该UUID已存在，调用run（避免重复创建）
		[[ "$(bocker_check "$uuid")" == 0 ]] && bocker_run "$@"
		# 创建btrfs子卷存储镜像
		btrfs subvolume create "$btrfs_path/$uuid" > /dev/null
		# 复制目录内容到镜像子卷（使用reflink减少拷贝）
		cp -rf --reflink=auto "$1"/* "$btrfs_path/$uuid" > /dev/null
		# 如果img.source文件不存在，则创建该文件，并记录镜像源目录
		[[ ! -f "$btrfs_path/$uuid"/img.source ]] && echo "$1" > "$btrfs_path/$uuid"/img.source
		# 输出创建成功的镜像ID
		echo "Created: $uuid"
	else
		# 目录不存在时提示错误
		echo "No directory named '$1' exists"
	fi
}

# 从Docker Hub拉取镜像
# 使用方式：bocker pull <name> <tag>
function bocker_pull() { #HELP Pull an image from Docker Hub:\nBOCKER pull <name> <tag>
	# 获取Docker Hub认证Token
	token="$(curl -sL -o /dev/null -D- -H 'X-Docker-Token: true' "https://index.docker.io/v1/repositories/$1/images" | tr -d '\r' | awk -F ': *' '$1 == "X-Docker-Token" { print $2 }')"
	# 定义Docker镜像仓库地址
	registry='https://registry-1.docker.io/v1'
	# 通过镜像名+标签获取镜像ID
	id="$(curl -sL -H "Authorization: Token $token" "$registry/repositories/$1/tags/$2" | sed 's/"//g')"
	# 校验镜像ID长度（64位），不合法则提示并退出
	[[ "${#id}" -ne 64 ]] && echo "No image named '$1:$2' exists" && exit 1
	# 获取镜像的祖先层ID列表
	ancestry="$(curl -sL -H "Authorization: Token $token" "$registry/images/$id/ancestry")"
	# 解析祖先层ID（去除特殊字符，拆分为数组）
	IFS=',' && ancestry=(${ancestry//[\[\] \"]/}) && IFS=' \n\t'; 
	# 创建临时目录存储镜像层（生成唯一UUID）
	tmp_uuid="$(uuidgen)" && mkdir /tmp/"$tmp_uuid"
	# 遍历所有镜像层，下载并解压
	for id in "${ancestry[@]}"; do
		# 下载镜像层压缩包
		curl -#L -H "Authorization: Token $token" "$registry/images/$id/layer" -o /tmp/"$tmp_uuid"/layer.tar
		# 解压到临时目录，然后删除压缩包
		tar xf /tmp/"$tmp_uuid"/layer.tar -C /tmp/"$tmp_uuid" && rm /tmp/"$tmp_uuid"/layer.tar
	done
	# 记录镜像源（Docker Hub的镜像名+标签）
	echo "$1:$2" > /tmp/"$tmp_uuid"/img.source
	# 调用init创建镜像，然后清理临时目录
	bocker_init /tmp/"$tmp_uuid" && rm -rf /tmp/"$tmp_uuid"
}

# 删除镜像或容器
# 使用方式：bocker rm <image_id or container_id>
function bocker_rm() { #HELP Delete an image or container:\nBOCKER rm <image_id or container_id>
	# 检查镜像/容器是否存在，不存在则提示并退出
	[[ "$(bocker_check "$1")" == 1 ]] && echo "No container named '$1' exists" && exit 1
	# 删除对应的btrfs子卷
	btrfs subvolume delete "$btrfs_path/$1" > /dev/null
	# 删除对应的cgroup配置（忽略错误，如cgroup不存在）
	cgdelete -g "$cgroups:/$1" &> /dev/null || true
	# 输出删除成功的ID
	echo "Removed: $1"
}

# 列出所有镜像
# 使用方式：bocker images
function bocker_images() { #HELP List images:\nBOCKER images
	# 输出表头（镜像ID、源）
	echo -e "IMAGE_ID\t\tSOURCE"
	# 遍历所有img_前缀的镜像子卷
	for img in "$btrfs_path"/img_*; do
		# 获取镜像ID（子卷basename）
		img=$(basename "$img")
		# 输出镜像ID和对应的源信息
		echo -e "$img\t\t$(cat "$btrfs_path/$img/img.source")"
	done
}

# 列出所有容器
# 使用方式：bocker ps
function bocker_ps() { #HELP List containers:\nBOCKER ps
	# 输出表头（容器ID、执行命令）
	echo -e "CONTAINER_ID\t\tCOMMAND"
	# 遍历所有ps_前缀的容器子卷
	for ps in "$btrfs_path"/ps_*; do
		# 获取容器ID（子卷basename）
		ps=$(basename "$ps")
		# 输出容器ID和对应的执行命令
		echo -e "$ps\t\t$(cat "$btrfs_path/$ps/$ps.cmd")"
	done
}

# 创建并运行容器
# 使用方式：bocker run <image_id> <command>
function bocker_run() { #HELP Create a container:\nBOCKER run <image_id> <command>
	# 生成容器唯一ID（前缀ps_，随机数范围42002-42254）
	uuid="ps_$(shuf -i 42002-42254 -n 1)"
	# 检查基础镜像是否存在，不存在则提示并退出
	[[ "$(bocker_check "$1")" == 1 ]] && echo "No image named '$1' exists" && exit 1
	# 若容器UUID冲突，递归重试创建
	[[ "$(bocker_check "$uuid")" == 0 ]] && echo "UUID conflict, retrying..." && bocker_run "$@" && return
	# 提取容器要执行的命令（第二个及以后参数）
	cmd="${@:2}" 
	# 生成容器IP（取UUID最后3位，去除0）
	ip="$(echo "${uuid: -3}" | sed 's/0//g')" 
	# 生成容器MAC地址后缀
	mac="${uuid: -3:1}:${uuid: -2}"
	# 创建veth虚拟网卡对（容器与主机通信）
	ip link add dev veth0_"$uuid" type veth peer name veth1_"$uuid"
	# 启动主机侧veth网卡
	ip link set dev veth0_"$uuid" up
	# 将主机侧veth网卡加入bridge0网桥
	ip link set veth0_"$uuid" master bridge0
	# 创建容器网络命名空间
	ip netns add netns_"$uuid"
	# 将容器侧veth网卡移入容器网络命名空间
	ip link set veth1_"$uuid" netns netns_"$uuid"
	# 在容器命名空间中启动回环网卡
	ip netns exec netns_"$uuid" ip link set dev lo up
	# 设置容器网卡MAC地址
	ip netns exec netns_"$uuid" ip link set veth1_"$uuid" address 02:42:ac:11:00"$mac"
	# 设置容器IP地址（10.0.0.xxx/24）
	ip netns exec netns_"$uuid" ip addr add 10.0.0."$ip"/24 dev veth1_"$uuid"
	# 启动容器侧veth网卡
	ip netns exec netns_"$uuid" ip link set dev veth1_"$uuid" up
	# 设置容器默认网关
	ip netns exec netns_"$uuid" ip route add default via 10.0.0.1
	# 基于镜像创建容器btrfs子卷（快照）
	btrfs subvolume snapshot "$btrfs_path/$1" "$btrfs_path/$uuid" > /dev/null
	# 设置容器DNS服务器（8.8.8.8）
	echo 'nameserver 8.8.8.8' > "$btrfs_path/$uuid"/etc/resolv.conf
	# 记录容器执行的命令
	echo "$cmd" > "$btrfs_path/$uuid/$uuid.cmd"
	# 创建容器对应的cgroup组
	cgcreate -g "$cgroups:/$uuid"
	# 设置CPU份额（默认512，可通过BOCKER_CPU_SHARE覆盖）
	: "${BOCKER_CPU_SHARE:=512}" && cgset -r cpu.shares="$BOCKER_CPU_SHARE" "$uuid"
	# 设置内存限制（默认512MB，可通过BOCKER_MEM_LIMIT覆盖，转换为字节）
	: "${BOCKER_MEM_LIMIT:=512}" && cgset -r memory.limit_in_bytes="$((BOCKER_MEM_LIMIT * 1000000))" "$uuid"
	# 执行容器命令：
	# 1. 进入指定cgroup资源组
	# 2. 进入指定网络命名空间
	# 3. 进行资源隔离：-f 后台运行，-m 挂载隔离, -u 主机名隔离, -i 进程通信隔离, -p PID隔离, --mount-proc 挂载全新的/proc
	# 4. chroot切换到容器根目录
	# 5. 在容器的隔离环境中，启动一个sh，先挂载proc，然后执行传入的命令cmd
	# 日志输出到容器log文件
	#
	# 执行效果
	# 1. 执行cgexec -g "$cgroups:$uuid"，将后续全部子进程都打上打内核标签，cgexec命令退出，后续进程变成孤儿，后续进程的父进程都会变成宿主机的init进程（PID=1）
	# 2. 执行ip netns exec netns_"$uuid"，切换网络命名空间，ip命令退出
	# 3. 执行unshare -fmuip --mount-proc chroot /var/bocker/ps_$uuid /bin/sh -c "/bin/mount -t proc proc /proc && $cmd"，开启容器服务
	# 4. 此时宿主内能看到三个进程：init（PID=1） -> unshare -> $cmd，要注意pid隔离其实只是对容器进程做隐藏，对宿主机是透明的，但同一个进程会有两个pid
	# 5. 此时容器内能看到一个进程：$cmd（PID=1）
	cgexec -g "$cgroups:$uuid" \
		ip netns exec netns_"$uuid" \
		unshare -fmuip --mount-proc \
		chroot "$btrfs_path/$uuid" \
		/bin/sh -c "/bin/mount -t proc proc /proc && $cmd" \
		2>&1 | tee "$btrfs_path/$uuid/$uuid.log" || true
	# 容器退出后，删除veth网卡对
	ip link del dev veth0_"$uuid"
	# 删除容器网络命名空间
	ip netns del netns_"$uuid"
}

# 在运行中的容器执行命令
# 使用方式：bocker exec <container_id> <command>
function bocker_exec() { #HELP Execute a command in a running container:\nBOCKER exec <container_id> <command>
	# 检查容器是否存在，不存在则提示并退出
	[[ "$(bocker_check "$1")" == 1 ]] && echo "No container named '$1' exists" && exit 1
	# 查找容器对应的进程ID
	# 进程父子关系：unshare进程(父进程) → 容器业务进程(比如/bin/sh，最终要找的就是它)
	# 1.先通过内括号，找到unshare进程
	# 2.然后通过外括号，找到unshare进程的所有子进程，而且应该只有一个
	cid="$(ps o ppid,pid | grep "^$(ps o pid,cmd | grep -E "^\ *[0-9]+ unshare.*$1" | awk '{print $1}')" | awk '{print $2}')"
	# 检查进程ID是否合法，不合法则提示容器未运行
	[[ ! "$cid" =~ ^\ *[0-9]+$ ]] && echo "Container '$1' exists but is not running" && exit 1
	# 进入容器命名空间，执行指定命令
	# -t 容器业务进程pid, -m 挂载隔离, -u 主机名隔离, -i 进程通信隔离, -n 网络隔离,-p PID隔离, chroot切换到容器根目录
	nsenter -t "$cid" -m -u -i -n -p chroot "$btrfs_path/$1" "${@:2}"
}

# 查看容器日志
# 使用方式：bocker logs <container_id>
function bocker_logs() { #HELP View logs from a container:\nBOCKER logs <container_id>
	# 检查容器是否存在，不存在则提示并退出
	[[ "$(bocker_check "$1")" == 1 ]] && echo "No container named '$1' exists" && exit 1
	# 输出容器日志文件内容
	cat "$btrfs_path/$1/$1.log"
}

# 将容器提交为镜像
# 使用方式：bocker commit <container_id> <image_id>
function bocker_commit() { #HELP Commit a container to an image:\nBOCKER commit <container_id> <image_id>
	# 检查源容器是否存在，不存在则提示并退出
	[[ "$(bocker_check "$1")" == 1 ]] && echo "No container named '$1' exists" && exit 1
	# 检查目标镜像是否存在，不存在则提示并退出
	[[ "$(bocker_check "$2")" == 1 ]] && echo "No image named '$2' exists" && exit 1
	# 删除原有目标镜像，基于容器创建新镜像（快照）
	bocker_rm "$2" && btrfs subvolume snapshot "$btrfs_path/$1" "$btrfs_path/$2" > /dev/null
	# 输出创建成功的镜像ID
	echo "Created: $2"
}

# 显示帮助信息
# 使用方式：bocker help
function bocker_help() { #HELP Display this message:\nBOCKER help
	# 提取脚本中#HELP注释，格式化输出帮助信息
	sed -n "s/^.*#HELP\\s//p;" < "$1" | sed "s/\\\\n/\n\t/g;s/$/\n/;s!BOCKER!${1/!/\\!}!g"
}

# 若未传入任何参数，显示帮助信息
[[ -z "${1-}" ]] && bocker_help "$0"
# 匹配第一个参数，执行对应的函数
case $1 in
	pull|init|rm|images|ps|run|exec|logs|commit) bocker_"$1" "${@:2}" ;;
	# 无匹配命令时显示帮助
	*) bocker_help "$0" ;;
esac
