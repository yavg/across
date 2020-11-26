###### Tips
* 通过安装[caddy](https://github.com/caddyserver/caddy/releases)和[xray](https://github.com/XTLS/Xray-core/releases)配置`vless + vmess + trojan + ss+xray-plugin + naiveproxy`**共用443端口**  
* 参考：[lxhao61](https://github.com/lxhao61/integrated-examples) && [xray](https://github.com/XTLS/Xray-examples)  
* 参数说明：
  1. `uuid`: 作为服务端账号和密码和路径等参数，**详情查看输出信息**,生成uuid命令: `cat /proc/sys/kernel/random/uuid`
  2. `my.domain.com`: 域名,由caddy管理证书和处理tls
* 安装:
```bash
bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/xray/xray_whatever_uuid.sh) uuid my.domain.com
```
* 卸载:
```bash
apt purge caddy -y
bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) --remove
systemctl disable xray; rm -rf /usr/local/etc/xray /var/log/xray
/root/.acme.sh/acme.sh --uninstall; rm -rf /root/.acme.sh
```
