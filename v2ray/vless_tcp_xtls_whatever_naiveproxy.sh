#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH

# Tips: 个人使用 仅供参考 当前配置 https://github.com/v2fly/v2ray-examples/tree/master/VLESS-TCP-XTLS-WHATEVER + trojan + ss+v2ray-plugin + naiveproxy
## 部分配置参考：https://github.com/lxhao61/integrated-examples
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/v2ray/vless_tcp_xtls_whatever_naiveproxy.sh) my.domain.com
# uninstall: apt purge caddy -y; bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove; systemctl disable v2ray; rm -rf /usr/local/etc/v2ray /var/log/v2ray; /root/.acme.sh/acme.sh --uninstall

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

########
[[ $# != 1 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com && exit 1
domain="$1"
v2my_uuid=$(cat /proc/sys/kernel/random/uuid)
xtlsflow="xtls-rprx-direct"
trojanpassword="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
vlesswspath="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
vmesstcppath="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
vmesswspath="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
ssmethod="none"
sspassword="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
sswspath="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
ssbase64info="$(echo -n "${ssmethod}:${sspassword}" | base64 | tr "\n" " " | sed s/[[:space:]]//g | tr -- "+/=" "-_ " | sed -e 's/ *$//g')"
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
                "clients": [{"id": "$v2my_uuid","flow": "$xtlsflow"}],"decryption": "none",
                "fallbacks": [
                    {"dest": 8888,"xver": 0},
                    {"alpn": "h2","dest": 88,"xver": 0},
                    {"path": "/$vlesswspath","dest": 1234,"xver": 1},
                    {"path": "/$vmesstcppath","dest": 2345,"xver": 1},
                    {"path": "/$vmesswspath","dest": 3456,"xver": 1},
                    {"path": "/$sswspath","dest": 4567,"xver": 0}
                ]
            },
            "streamSettings": {"network": "tcp","security": "xtls","xtlsSettings": {"alpn": ["h2","http/1.1"],"certificates": [{"certificateFile": "/usr/local/etc/v2ray/v2ray.crt","keyFile": "/usr/local/etc/v2ray/v2ray.key"}]}}
        },
        {
            "port": 8888,"listen": "127.0.0.1","protocol": "trojan",
            "settings": {"clients": [{"password":"$trojanpassword"}],"fallbacks": [{"dest": 88,"xver": 0}]},
            "streamSettings": {"security": "none","network": "tcp"}
        },
        {
            "port": 1234,"listen": "127.0.0.1","protocol": "vless",
            "settings": {"clients": [{"id": "$v2my_uuid"}],"decryption": "none"},
            "streamSettings": {"network": "ws","security": "none","wsSettings": {"acceptProxyProtocol": true,"path": "/$vlesswspath"}}
        },
        {
            "port": 2345,"listen": "127.0.0.1","protocol": "vmess",
            "settings": {"clients": [{"id": "$v2my_uuid"}]},
            "streamSettings": {"network": "tcp","security": "none","tcpSettings": {"acceptProxyProtocol": true,"header": {"type": "http","request": {"path": ["/$vmesstcppath"]}}}}
        },
        {
            "port": 3456,"listen": "127.0.0.1","protocol": "vmess",
            "settings": {"clients": [{"id": "$v2my_uuid"}]},
            "streamSettings": {"network": "ws","security": "none","wsSettings": {"acceptProxyProtocol": true,"path": "/$vmesswspath"}}
        },
        {
            "port": "4567","listen": "127.0.0.1","tag": "onetag","protocol": "dokodemo-door",
            "settings": {"address": "v1.mux.cool","network": "tcp","followRedirect": false},
            "streamSettings": {"security": "none","network": "ws","wsSettings": {"path": "/$sswspath"}}
        },
        {
            "port": 7654,"listen": "127.0.0.1","protocol": "shadowsocks",
            "settings": {"method": "$ssmethod","password": "$sspassword","network": "tcp,udp"},
            "streamSettings": {"security": "none","network": "domainsocket","dsSettings": {"path": "apath","abstract": true}}
        },
        {"port": 9876,"listen": "127.0.0.1","tag": "naiveproxyupstream","protocol": "socks","settings": {"udp": true}}
    ],
    "outbounds": 
    [
        {"protocol": "freedom","tag": "direct","settings": {}},
        {"protocol": "blackhole","tag": "blocked","settings": {}},
        {"protocol": "freedom","tag": "twotag","streamSettings": {"network": "domainsocket","dsSettings": {"path": "apath","abstract": true}}}
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

# caddy as webserver, install acme.sh installcert
systemctl start caddy
apt install socat -y
curl https://get.acme.sh | sh && source  ~/.bashrc
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --issue -d $domain --keylength ec-256 --webroot /usr/share/caddy/
/root/.acme.sh/acme.sh --installcert -d $domain --ecc --fullchain-file /usr/local/etc/v2ray/v2ray.crt --key-file /usr/local/etc/v2ray/v2ray.key --reloadcmd "service v2ray restart"
chown -R nobody:nogroup /usr/local/etc/v2ray || chown -R nobody:nobody /usr/local/etc/v2ray

# caddy with naive fork of forwardproxy: https://github.com/klzgrad/forwardproxy
naivecaddyURL="https://github.com/mixool/across/raw/master/source/caddy.gz"
rm -rf /usr/bin/caddy
wget --no-check-certificate -O - $naivecaddyURL | gzip -d > /usr/bin/caddy && chmod +x /usr/bin/caddy
sed -i "s/caddy\/Caddyfile$/caddy\/Caddyfile\.json/g" /lib/systemd/system/caddy.service

# caddy naiveproxy secrets
username="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
password="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
probe_resistance="$(tr -dc 'a-z0-9' </dev/urandom | head -c 32).com"

# caddy json config
cat <<EOF >/etc/caddy/Caddyfile.json
{
    "admin": {"disabled": true},
    "apps": {
        "http": {
            "servers": {
                "srv0": {
                    "listen": ["127.0.0.1:88"],
                    "allow_h2c": true,
                    "routes": [{
                        "handle": [{
                            "handler": "forward_proxy",
                            "hide_ip": true,
                            "hide_via": true,
                            "auth_user": "$username",
                            "auth_pass": "$password",
                            "probe_resistance": {"domain": "$probe_resistance"},
                            "upstream": "socks5://127.0.0.1:9876"
                        }]
                    },{
                        "handle": [{
                            "handler": "file_server",
                            "root": "/usr/share/caddy"
                        }],
                        "terminal": true
                    }]
                }
            }
        }
    }
}
EOF

# systemctl service info
systemctl daemon-reload
echo; echo $(date) caddy status:
systemctl enable caddy && systemctl restart caddy && sleep 1 && systemctl status caddy | more | grep -A 2 "caddy.service"
echo; echo $(date) v2ray status:
systemctl enable v2ray && systemctl restart v2ray && sleep 1 && systemctl status v2ray | more | grep -A 2 "v2ray.service"

# info
cat <<EOF >$TMPFILE
$(date) v2ray client outbounds config info:
        {
            "protocol": "vless",
            "tag": "vless_tcp_$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$v2my_uuid","flow": "$xtlsflow","encryption": "none"}]}]},
            "streamSettings": {"security": "xtls","xtlsSettings": {"serverName": "$domain"}}
        },
        
        {
            "protocol": "vless",
            "tag": "vless_ws_$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$v2my_uuid","encryption": "none"}]}]},
            "streamSettings": {"network": "ws","security": "tls","tlsSettings": {"serverName": "$domain"},"wsSettings": {"path": "/$vlesswspath","headers": {"Host": "$domain"}}}
        },
        
        {
            "protocol": "vmess",
            "tag": "vmess_tcp_$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$v2my_uuid"}]}]},
            "streamSettings": {"security": "tls","tlsSettings": {"serverName": "$domain"},"tcpSettings": {"header":{"type": "http","request": {"path": ["/$vmesstcppath"]}}}}
        },
        
        {
            "protocol": "vmess",
            "tag": "vmess_ws_$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$v2my_uuid"}]}]},
            "streamSettings": {"network": "ws","security": "tls","tlsSettings": {"serverName": "$domain"},"wsSettings": {"path": "/$vmesswspath","headers": {"Host": "$domain"}}}
        },

$(date) $domain trojan password: $trojanpassword

$(date) $domain shadowsocks info:   
ss://${ssbase64info}@${domain}:443?plugin=v2ray-plugin%3Bpath%3D%2F${sswspath}%3Bhost%3D${domain}%3Btls#${domain}

$(date) $domain naiveproxy info:
username: $username
password: $password
probe_resistance: $probe_resistance
proxy: https://$username:$password@$domain

EOF

cat $TMPFILE
# done