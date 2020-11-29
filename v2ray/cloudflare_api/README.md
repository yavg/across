###### Tips
* 通过[caddy](https://github.com/caddyserver/caddy/releases)|[v2ray](https://github.com/v2fly/v2ray-core/releases)配置`vless + vmess + trojan + ss+xray-plugin + naiveproxy`**共用443端口**  
* 此版本caddy的tls模块使用(cloudflare with api)[https://caddyserver.com/docs/json/apps/tls/automation/policies/issuer/acme/challenges/dns/provider/cloudflare/api_token]申请证书  
* 参考：[v2fly-examples](https://github.com/v2fly/v2ray-examples) && [lxhao61](https://github.com/lxhao61/integrated-examples)
* 安装:
```bash
bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/v2ray/cloudflare_api/everapi.sh) uuid my.domain.com
```
* 卸载:
```bash
apt purge caddy -y
bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove; systemctl disable v2ray; systemctl stop v2ray; rm -rf /usr/local/etc/v2ray /var/log/v2ray
```
