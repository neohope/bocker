# Bocker（补充代码注释）
用约100行bash脚本实现的Docker。

  * [前提条件](#前提条件)
  * [示例用法](#示例用法)
  * [已实现的功能](#功能-当前已实现)
  * [暂未实现的功能](#功能-尚未实现)
  * [许可证](#许可证)

## 前提条件

运行bocker需要安装以下软件包：

* btrfs-progs
* curl
* iproute2
* iptables
* libcgroup-tools
* util-linux >= 2.25.2
* coreutils >= 7.5

由于大多数发行版预装的util-linux版本不够新，你可能需要从[这里](https://www.kernel.org/pub/linux/utils/util-linux/v2.25/)获取源码并自行编译。

此外，你的系统还需要完成以下配置：

* 一个btrfs文件系统挂载在 `/var/bocker` 目录下
* 一个名为 `bridge0` 的网络桥接设备，且配置IP为 10.0.0.1/24
* 在 `/proc/sys/net/ipv4/ip_forward` 中启用IP转发
* 配置防火墙，将 `bridge0` 的流量路由到物理网络接口

为了方便使用，本项目包含一个Vagrantfile文件，可用于构建所需的运行环境。

即使你满足上述所有前提条件，也建议**在虚拟机中运行bocker**。bocker需要以root权限运行，并且会修改网络接口、路由表和防火墙规则等系统配置。**我无法保证它不会破坏你的系统**。

## 示例用法

```
$ bocker pull centos 7
######################################################################## 100.0%
######################################################################## 100.0%
######################################################################## 100.0%
Created: img_42150

$ bocker images
IMAGE_ID        SOURCE
img_42150       centos:7

$ bocker run img_42150 cat /etc/centos-release
CentOS Linux release 7.1.1503 (Core)

$ bocker ps
CONTAINER_ID       COMMAND
ps_42045           cat /etc/centos-release

$ bocker logs ps_42045
CentOS Linux release 7.1.1503 (Core)

$ bocker rm ps_42045
Removed: ps_42045

$ bocker run img_42150 which wget
which: no wget in (/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin)

$ bocker run img_42150 yum install -y wget
Installing : wget-1.14-10.el7_0.1.x86_64                                  1/1
Verifying  : wget-1.14-10.el7_0.1.x86_64                                  1/1
Installed  : wget.x86_64 0:1.14-10.el7_0.1
Complete!

$ bocker ps
CONTAINER_ID       COMMAND
ps_42018           yum install -y wget
ps_42182           which wget

$ bocker commit ps_42018 img_42150
Removed: img_42150
Created: img_42150

$ bocker run img_42150 which wget
/usr/bin/wget

$ bocker run img_42150 cat /proc/1/cgroup
...
4:memory:/ps_42152
3:cpuacct,cpu:/ps_42152

$ cat /sys/fs/cgroup/cpu/ps_42152/cpu.shares
512

$ cat /sys/fs/cgroup/memory/ps_42152/memory.limit_in_bytes
512000000

$ BOCKER_CPU_SHARE=1024 \
	BOCKER_MEM_LIMIT=1024 \
	bocker run img_42150 cat /proc/1/cgroup
...
4:memory:/ps_42188
3:cpuacct,cpu:/ps_42188

$ cat /sys/fs/cgroup/cpu/ps_42188/cpu.shares
1024

$ cat /sys/fs/cgroup/memory/ps_42188/memory.limit_in_bytes
1024000000
```

## 功能：当前已实现

* `docker build` †
* `docker pull`
* `docker images`
* `docker ps`
* `docker run`
* `docker exec`
* `docker logs`
* `docker commit`
* `docker rm` / `docker rmi`
* Networking
* Quota Support / CGroups

† `bocker init` 提供了 `docker build` 的极简实现版本

## 功能：尚未实现

* Data Volume Containers
* Data Volumes
* Port Forwarding

## 许可证

版权所有 (C) 2015 Peter Wilmott

本程序是自由软件：你可以依据自由软件基金会发布的GNU通用公共许可证（第三版）或（可选）任何更新版本的条款，重新分发和/或修改本程序。

发布本程序的目的是希望它能发挥作用，但**不提供任何担保**；甚至没有隐含的适销性或特定用途适用性的担保。有关详细信息，请参阅GNU通用公共许可证。

你应已收到本程序附带的GNU通用公共许可证副本。如果没有，请参阅 <http://www.gnu.org/licenses/>。
