###### Tips
* 通过[caddy](https://github.com/caddyserver/caddy/releases)和[xray](https://github.com/XTLS/Xray-core/releases)以及[acme.sh](https://github.com/acmesh-official/acme.sh)配置`vless + vmess + trojan + ss+xray-plugin + naiveproxy`**共用443端口**  
* 参考：[lxhao61](https://github.com/lxhao61/integrated-examples) && [xray](https://github.com/XTLS/Xray-examples)  
* 安装:
```bash
bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/xray/xray_whatever_uuid.sh) uuid my.domain.com
```
* 卸载:
```bash
apt purge caddy -y
bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) --remove; systemctl disable xray; rm -rf /usr/local/etc/xray /var/log/xray
/root/.acme.sh/acme.sh --uninstall; rm -rf /root/.acme.sh
```
