#!/bin/bash
# Usage: debian 10 & 9 && linux-image-cloud-amd64 bbr
#   bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/kvmbbr/bbr.sh)        # 仅开启bbr
#   bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/kvmbbr/bbr.sh) cloud  # 升级最新cloud内核并开启bbr
#   uninstall: apt purge -t buster-backports linux-image-cloud-amd64 linux-headers-cloud-amd64
### tips: personal use only

# only root can run this script
[[ $EUID -ne 0 ]] && echo "Error, This script must be run as root!" && exit 1

# version stretch || buster
version=$(cat /etc/os-release | grep -oE "VERSION_ID=\"(9|10)\"" | grep -oE "(9|10)")
if [[ $version == "9" ]]; then
    backports_version="stretch-backports-sloppy"
else
    [[ $version != "10" ]] && echo "Error, OS should be debian stretch or buster " && exit 1 || backports_version="buster-backports"
fi

# cloud kernel install
if [[ "$1" == "cloud" ]]; then
    echo -e "deb http://deb.debian.org/debian $backports_version main\ndeb http://http.us.debian.org/debian sid main" > /etc/apt/sources.list.d/$backports_version.list
    apt update 
    apt -t $backports_version install linux-image-cloud-amd64 linux-headers-cloud-amd64 -y
fi

# bbr 
modprobe tcp_bbr
cat /etc/modules-load.d/modules.conf | grep -q "tcp_bbr" || echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
cat /etc/sysctl.conf | grep -q "net.core.default_qdisc = fq" || echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
cat /etc/sysctl.conf | grep -q "net.ipv4.tcp_congestion_control = bbr" || echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
sysctl -p

# reboot
[[ "$1" == "cloud" ]] && echo "OK, OS rebooting.. " && reboot
