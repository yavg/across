#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH

# Tips: 个人使用 仅供参考 当前配置 https://github.com/v2fly/v2ray-examples/tree/master/VLESS-TCP-XTLS-WHATEVER
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/v2ray/vless_tcp_xtls_whatever.sh) my.domain.com CF_Key CF_Email
# uninstall: apt purge caddy -y; bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove; systemctl disable v2ray; rm -rf /usr/local/etc/v2ray /var/log/v2ray; /root/.acme.sh/acme.sh --uninstall

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

########
[[ $# != 3 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com CF_Key CF_Email && exit 1
domain="$1" && export CF_Key="$2" && export CF_Email="$3"
v2my_uuid=$(cat /proc/sys/kernel/random/uuid)
xtlsflow="xtls-rprx-direct"
vlesswspath="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
vmesstcppath="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
vmesswspath="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
########

# dpkg install caddy
caddyURL="$(wget -qO-  https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_amd64\.deb" | cut -f4 -d\" | head -n1)"
wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE

# install v2ray
bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# install acme.sh installcert
apt install socat -y
curl https://get.acme.sh | sh && source  ~/.bashrc
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --issue --dns dns_cf --keylength ec-256 -d $domain
/root/.acme.sh/acme.sh --installcert -d $domain --ecc --fullchain-file /usr/local/etc/v2ray/v2ray.crt --key-file /usr/local/etc/v2ray/v2ray.key --reloadcmd "service v2ray restart"
chown -R nobody:nogroup /usr/local/etc/v2ray || chown -R nobody:nobody /usr/local/etc/v2ray

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
                    {"dest": 80},
                    {"path": "/$vlesswspath","dest": 1234,"xver": 1},
                    {"path": "/$vmesstcppath","dest": 2345,"xver": 1},
                    {"path": "/$vmesswspath","dest": 3456,"xver": 1}
                ]
            },
            "streamSettings": {"network": "tcp","security": "xtls","xtlsSettings": {"alpn": ["http/1.1"],"certificates": [{"certificateFile": "/usr/local/etc/v2ray/v2ray.crt","keyFile": "/usr/local/etc/v2ray/v2ray.key"}]}}
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
        }
    ],
    "outbounds": 
    [
        {"protocol": "freedom","tag": "direct","settings": {}},
        {"protocol": "blackhole","tag": "blocked","settings": {}}
    ],

    "routing": 
    {
        "rules": 
        [
            {"type": "field","outboundTag": "blocked","ip": ["geoip:private"]},
            {"type": "field","outboundTag": "blocked","domain": ["geosite:private","geosite:category-ads-all"]}
        ]
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
EOF

echo; echo $(date) v2ray client outbounds config info:
cat $TMPFILE
# done
