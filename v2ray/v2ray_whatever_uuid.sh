#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH

# Tips: vless + trojan + ss+v2ray-plugin + naiveproxy | 传入参数$uuid作为服务端账号和密码参数，uuid-[vless|trojan|ss]作为服务端路径参数，自用uuid务必妥善保存，如有分享需求，建议生成一个分享专用的uuid，其它查看输出信息  
# integrated-examples：https://github.com/lxhao61/integrated-examples | uuid=$(cat /proc/sys/kernel/random/uuid) 
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/v2ray/v2ray_whatever_uuid.sh) cloudflare_Email_Address cloudflare_Global_API_Key uuid my.domain.com  
# uninstall : apt purge caddy -y; bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove; /root/.acme.sh/acme.sh --uninstall; systemctl disable v2ray; rm -rf /usr/local/etc/v2ray /var/log/v2ray /root/.acme.sh   

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

########
[[ $# != 4 ]] && echo Err  !!! Useage: bash this_script.sh cloudflare_Email_Address cloudflare_Global_API_Key uuid my.domain.com && exit 1
export CF_Email="$1" && export CF_Key="$2" && uuid="$3" && domain="$4"
xtlsflow="xtls-rprx-direct" && ssmethod="none"
vlesspath="${uuid}-vless"
trojanpath="${uuid}-trojan"
shadowsockspath="${uuid}-ss"
########

# v2ray install
bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# config v2ray
cat <<EOF >/usr/local/etc/v2ray/config.json
{
    "log": {"loglevel": "warning"},
    "inbounds": [
        {
            "port": 443,"protocol": "vless",
            "settings": {
                "clients": [{"id": "$uuid","flow": "$xtlsflow"}],"decryption": "none",
                "fallbacks": [
                    {"dest": "/usr/local/etc/v2ray/trojan"},
                    {"dest": "/usr/local/etc/v2ray/trojanws","path": "/$trojanpath"},
                    {"dest": "/usr/local/etc/v2ray/vlessws","path": "/$vlesspath"},
                    {"dest": 50001,"path": "/$shadowsockspath"}
                ]
            },
            "streamSettings": {"network": "tcp","security": "xtls","xtlsSettings": {"alpn": ["h2","http/1.1"],"certificates": [{"certificateFile": "/usr/local/etc/v2ray/v2ray.crt","keyFile": "/usr/local/etc/v2ray/v2ray.key"}]}}
        },
        {
            "listen": "/usr/local/etc/v2ray/trojan","protocol": "trojan",
            "settings": {"clients": [{"password":"$uuid"}],"fallbacks": [{"dest": 50080}]},
            "streamSettings": {"security": "none","network": "tcp"}
        },
        {
            "listen": "/usr/local/etc/v2ray/trojanws","protocol": "trojan",
            "settings": {"clients": [{"password":"$uuid"}]},
            "streamSettings": {"network": "ws","wsSettings": {"path": "/$trojanpath"}}
        },
        {
            "listen": "/usr/local/etc/v2ray/vlessws","protocol": "vless",
            "settings": {"clients": [{"id": "$uuid"}],"decryption": "none"},
            "streamSettings": {"network": "ws","security": "none","wsSettings": {"path": "/$vlesspath"}}
        },
        {
            "port": "50001","listen": "127.0.0.1","tag": "onetag","protocol": "dokodemo-door",
            "settings": {"address": "v1.mux.cool","network": "tcp","followRedirect": false},
            "streamSettings": {"security": "none","network": "ws","wsSettings": {"path": "/$shadowsockspath"}}
        },
        {
            "port": 50002,"listen": "127.0.0.1","protocol": "shadowsocks",
            "settings": {"method": "$ssmethod","password": "$uuid","network": "tcp,udp"},
            "streamSettings": {"security": "none","network": "domainsocket","dsSettings": {"path": "/usr/local/etc/v2ray/ss"}}
        },
        {   "port": 59876,"listen": "127.0.0.1","tag": "naiveproxyupstream","protocol": "socks",
            "settings": {"auth": "password","accounts": [{"user": "$uuid","pass": "$uuid"}],"udp": true}
        }
    ],
    "outbounds": 
    [
        {"protocol": "freedom","tag": "direct","settings": {}},
        {"protocol": "blackhole","tag": "blocked","settings": {}},
        {"protocol": "freedom","tag": "twotag","streamSettings": {"network": "domainsocket","dsSettings": {"path": "/usr/local/etc/v2ray/ss"}}}
    ],

    "routing": 
    {
        "rules": 
        [
            {"type": "field","inboundTag": ["onetag"],"outboundTag": "twotag"},
            {"type": "field","outboundTag": "blocked","ip": ["geoip:private"]},
            {"type": "field","outboundTag": "blocked","domain": ["geosite:private","geosite:category-ads-all"]}
        ]
    }
}
EOF

# caddy install 
caddyURL="$(wget -qO-  https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_amd64\.deb" | cut -f4 -d\" | head -n1)"
wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE

# caddy with naive fork of forwardproxy: https://github.com/klzgrad/forwardproxy
naivecaddyURL="https://github.com/mixool/across/raw/master/source/caddy.gz"
rm -rf /usr/bin/caddy
wget --no-check-certificate -O - $naivecaddyURL | gzip -d > /usr/bin/caddy && chmod +x /usr/bin/caddy
sed -i "s/caddy\/Caddyfile$/caddy\/Caddyfile\.json/g" /lib/systemd/system/caddy.service

# caddy json config
cat <<EOF >/etc/caddy/Caddyfile.json
{
    "admin": {"disabled": true},
    "apps": {
        "http": {
            "servers": {
                "srv0": {
                    "listen": ["127.0.0.1:50080"],
                    "routes": [{
                        "handle": [{
                            "handler": "forward_proxy",
                            "hide_ip": true,
                            "hide_via": true,
                            "auth_user": "$uuid",
                            "auth_pass": "$uuid",
                            "probe_resistance": {"domain": "$uuid.com"},
                            "upstream": "socks5://$uuid:$uuid@127.0.0.1:59876"
                        }]
                    },{
                        "match": [{"host": ["$domain"]}],
                        "handle": [{
                            "handler": "file_server",
                            "root": "/usr/share/caddy"
                        }],
                        "terminal": true
                    }],
                    "automatic_https": {
                        "disable": true 
                    },
                    "allow_h2c": true
                }
            }
        }
    }
}
EOF

# acme.sh installcert
apt install socat -y
curl https://get.acme.sh | sh && source  ~/.bashrc
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --issue --dns dns_cf --keylength ec-256 -d $domain
/root/.acme.sh/acme.sh --installcert -d $domain --ecc --fullchain-file /usr/local/etc/v2ray/v2ray.crt --key-file /usr/local/etc/v2ray/v2ray.key --reloadcmd "service v2ray restart"
chown -R nobody:nogroup /usr/local/etc/v2ray || chown -R nobody:nobody /usr/local/etc/v2ray

# systemctl service info
systemctl daemon-reload && systemctl enable caddy v2ray && systemctl restart caddy v2ray && sleep 3 && systemctl status caddy v2ray | grep -A 2 "service"

# info
cat <<EOF >$TMPFILE
$(date) $domain vless:
uuid: $uuid
path: $vlesspath

$(date) $domain trojan:
password: $uuid
path: $trojanpath

$(date) $domain shadowsocks:   
ss://$(echo -n "${ssmethod}:${uuid}" | base64 | tr "\n" " " | sed s/[[:space:]]//g | tr -- "+/=" "-_ " | sed -e 's/ *$//g')@${domain}:443?plugin=v2ray-plugin%3Bpath%3D%2F${shadowsockspath}%3Bhost%3D${domain}%3Btls#${domain}

$(date) $domain naiveproxy:
probe_resistance: $uuid.com
proxy: https://$uuid:$uuid@$domain

$(date) Visit: https://$domain
EOF

cat $TMPFILE | tee /var/log/${TMPFILE##*/} && echo && echo $(date) Info saved: /var/log/${TMPFILE##*/}
# done