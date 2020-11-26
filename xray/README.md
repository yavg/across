###### Tips
* 通过安装[xray](https://github.com/XTLS/Xray-core/releases)和[caddy](https://github.com/caddyserver/caddy/releases)同时支持配置`vless + vmess + trojan + ss+xray-plugin + naiveproxy`10种模式，其中`vless`和`vmess`各配置了3种传输方式，`trojan`配置了2种传输方式，**共用443端口**  
* 更多配置参考：[lxhao61](https://github.com/lxhao61/integrated-examples) && [xray](https://github.com/XTLS/Xray-examples)  
* 参数说明：
  1. `uuid`: 作为服务端账号和密码和路径等参数，详情查看输出信息,生成uuid命令: `cat /proc/sys/kernel/random/uuid`
  2. `my.domain.com`: 域名,由caddy管理证书和处理TLS
* 安装: `bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/xray/xray_whatever_uuid.sh) uuid my.domain.com`
* 卸载: 
  1. `apt purge caddy -y`
  2. `bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) --remove; systemctl disable xray; rm -rf /usr/local/etc/xray /var/log/xray`
  3. `/root/.acme.sh/acme.sh --uninstall; rm -rf /root/.acme.sh`
