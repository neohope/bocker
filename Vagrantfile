# 定义要在虚拟机中执行的脚本内容
$script = <<SCRIPT
(
# 安装EPEL扩展源（CentOS 7）
rpm -i https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
# 静默安装所需依赖包（自动化工具、docker、git等）
yum install -y -q autoconf automake btrfs-progs docker gettext-devel git libcgroup-tools libtool python-pip

# 创建10GB的btrfs镜像文件
fallocate -l 10G ~/btrfs.img
# 创建bocker挂载目录
mkdir /var/bocker
# 格式化镜像文件为btrfs文件系统
mkfs.btrfs ~/btrfs.img
# 循环挂载btrfs镜像到/var/bocker目录
mount -o loop ~/btrfs.img /var/bocker

# 通过pip安装undocker工具（用于解压docker镜像）
pip install git+https://github.com/larsks/undocker
# 启动docker服务
systemctl start docker.service
# 拉取centos基础镜像
docker pull centos
# 将centos镜像导出并通过undocker解压到base-image目录
docker save centos | undocker -o base-image

# 克隆util-linux代码仓库（包含unshare工具）
git clone https://github.com/karelzak/util-linux.git
# 进入util-linux目录
cd util-linux
# 切换到v2.25.2版本标签
git checkout tags/v2.25.2
# 生成自动化构建配置文件
./autogen.sh
# 配置编译选项（禁用ncurses和python）
./configure --without-ncurses --without-python
# 编译代码
make
# 将编译后的unshare工具移动到系统可执行目录
mv unshare /usr/bin/unshare
# 返回上级目录
cd ..

# 创建软链接，将/vagrant/bocker映射到系统可执行目录
ln -s /vagrant/bocker /usr/bin/bocker

# 开启IP转发（用于网络桥接和NAT）
echo 1 > /proc/sys/net/ipv4/ip_forward
# 清空iptables现有规则
iptables --flush
# 添加NAT规则：bridge0网卡出站流量做地址伪装
iptables -t nat -A POSTROUTING -o bridge0 -j MASQUERADE
# 添加NAT规则：enp0s3网卡出站流量做地址伪装
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE

# 创建名为bridge0的桥接网络接口
ip link add bridge0 type bridge
# 为bridge0分配IP地址10.0.0.1/24
ip addr add 10.0.0.1/24 dev bridge0
# 启用bridge0网络接口
ip link set bridge0 up
) 2>&1  # 将标准错误重定向到标准输出，便于日志排查
SCRIPT

# 初始化Vagrant配置（版本2）
Vagrant.configure(2) do |config|
    # 指定虚拟机使用的基础镜像（CentOS 7）
	config.vm.box = 'puppetlabs/centos-7.0-64-nocm'
    # 设置SSH登录用户名
	config.ssh.username = 'root'
    # 设置SSH登录密码
	config.ssh.password = 'puppet'
    # 自动插入SSH密钥
	config.ssh.insert_key = 'true'
    # 通过shell脚本方式配置虚拟机，执行上述定义的$script脚本
	config.vm.provision 'shell', inline: $script
end
