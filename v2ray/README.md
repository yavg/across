# Tips
0. 通过安装v2ray+caddy同时配置vless + vmess + trojan + ss+v2ray-plugin + naiveproxy服务端，一共配置了了10种模式，其中vless和vmess各配置了3种传输方式，trojan配置了2种传输方式，均使用443端口
1. 更多配置参考：https://github.com/lxhao61/integrated-examples https://github.com/v2fly/v2ray-examples
2. 参数说明：
    uuid: 作为服务端账号和密码参数，uuid-[vless|vlessh2|vmesstcp|vmess|vmessh2|trojan|ss]作为服务端路径参数，其它客户端参数查看输出信息。自用uuid务必妥善保存，如有分享需求，建议生成一个分享专用的uuid: cat /proc/sys/kernel/random/uuid
    my.domain.com: 域名，caddy用80端口申请证书,443端口数据由layer4插件解开tls后转发至v2ray | caddy：xcaddy build --with github.com/mholt/caddy-l4 --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
3. install: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/v2ray/v2ray_whatever_uuid.sh) uuid my.domain.com
4. uninstall: 
    apt purge caddy -y
    bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove; systemctl disable v2ray; rm -rf /usr/local/etc/v2ray /var/log/v2ray