# Tips
* 通过安装`v2ray+caddy`同时配置`vless + vmess + trojan + ss+xray-plugin + naiveproxy`服务端，一共配置了了10种模式，其中`vless`和`vmess`各配置了3种传输方式，`trojan`配置了2种传输方式，均使用443端口  
* 更多配置参考：[lxhao61/integrated-examples](https://github.com/lxhao61/integrated-examples) && [v2fly/v2fly-examples](https://github.com/v2fly/v2ray-examples)  
* 参数说明：
  1. `uuid`: 作为服务端账号和密码参数，`uuid-[vless|vlessh2|vmesstcp|vmess|vmessh2|trojan|ss]`作为服务端路径参数，其它客户端参数查看输出信息。自用uuid务必妥善保存，如有分享需求，建议生成一个分享专用的uuid: `cat /proc/sys/kernel/random/uuid`
  2. `my.domain.com`: 域名,证书由caddy自动管理
* install: `bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/v2ray/v2ray_whatever_uuid.sh) uuid my.domain.com`
* uninstall: 
  1. `apt purge caddy -y`
  2. `bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) --remove; systemctl disable xray; rm -rf /usr/local/etc/xray /var/log/xray`
  3. `/root/.acme.sh/acme.sh --uninstall; rm -rf /root/.acme.sh`