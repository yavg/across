#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

########
[[ $# != 3 ]] && echo Err  !!! Useage: bash this_script.sh cloudflare_api uuid my.domain.com && exit 1
cloudflare_api="$1" && uuid="$2" && domain="$3"
vlesspath="${uuid}-vless"
vlessh2path="${uuid}-vlessh2"
vmesstcppath="${uuid}-vmesstcp"
vmesswspath="${uuid}-vmess"
vmessh2path="${uuid}-vmessh2"
trojanpath="${uuid}-trojan"
shadowsockspath="${uuid}-ss"
ssmethod="none"
########

# v2ray install
bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
chown -R nobody:nogroup /usr/local/etc/v2ray

# config v2ray
cat <<EOF >/usr/local/etc/v2ray/config.json
{
    "log": {"loglevel": "warning"},
    "inbounds": [
        {
            "port": 50000,"listen": "127.0.0.1","protocol": "vless",
            "settings": {
                "clients": [{"id": "$uuid"}],"decryption": "none",
                "fallbacks": [
                    {"dest": "@vlessws","path": "/$vlesspath"},
                    {"dest": "@vmessws","path": "/$vmesswspath"},
                    {"dest": "@vmesstcp","path": "/$vmesstcppath"},
                    {"dest": "@trojan"},
                    {"dest": "@trojanws","path": "/$trojanpath"},
                    {"dest": 50003,"path": "/$shadowsockspath"}
                ]
            },
            "streamSettings": {"network": "tcp","security": "none"}
        },
        {
            "listen": "@vlessws","protocol": "vless",
            "settings": {"clients": [{"id": "$uuid"}],"decryption": "none"},
            "streamSettings": {"network": "ws","security": "none","wsSettings": {"path": "/$vlesspath"}}
        },
        {
            "port": 50001,"listen": "127.0.0.1","protocol": "vless",
            "settings": {"clients": [{"id": "$uuid"}],"decryption": "none"},
            "streamSettings": {"network": "h2","httpSettings": {"host": ["$domain"],"path": "/$vlessh2path"}}
        },
        {
            "listen": "@vmesstcp","protocol": "vmess",
            "settings": {"clients": [{"id": "$uuid"}]},
            "streamSettings": {"network": "tcp","security": "none","tcpSettings": {"header": {"type": "http","request": {"path": ["/$vmesstcppath"]}}}}
        },
        {
            "listen": "@vmessws","protocol": "vmess",
            "settings": {"clients": [{"id": "$uuid"}]},
            "streamSettings": {"network": "ws","security": "none","wsSettings": {"path": "/$vmesswspath"}}
        },
        {
            "port": 50002,"listen": "127.0.0.1","protocol": "vmess",
            "settings": {"clients": [{"id": "$uuid"}]},
            "streamSettings": {"network": "h2","httpSettings": {"host": ["$domain"],"path": "/$vmessh2path"}}
        },
        {
            "listen": "@trojan","protocol": "trojan",
            "settings": {"clients": [{"password":"$uuid"}],"fallbacks": [{"dest": 50080}]},
            "streamSettings": {"security": "none","network": "tcp"}
        },
        {
            "listen": "@trojanws","protocol": "trojan",
            "settings": {"clients": [{"password":"$uuid"}]},
            "streamSettings": {"network": "ws","wsSettings": {"path": "/$trojanpath"}}
        },
        {
            "port": "50003","listen": "127.0.0.1","tag": "onetag","protocol": "dokodemo-door",
            "settings": {"address": "v1.mux.cool","network": "tcp","followRedirect": false},
            "streamSettings": {"security": "none","network": "ws","wsSettings": {"path": "/$shadowsockspath"}}
        },
        {
            "port": 50004,"listen": "127.0.0.1","protocol": "shadowsocks",
            "settings": {"method": "$ssmethod","password": "$uuid","network": "tcp,udp"},
            "streamSettings": {"security": "none","network": "domainsocket","dsSettings": {"path": "/usr/local/etc/v2ray/ss","abstract": true}}
        },
        {   "port": 59876,"listen": "127.0.0.1","tag": "naiveproxyupstream","protocol": "socks",
            "settings": {"auth": "password","accounts": [{"user": "$uuid","pass": "$uuid"}],"udp": true}
        }
    ],
    "outbounds": 
    [
        {"protocol": "freedom","tag": "direct","settings": {}},
        {"protocol": "blackhole","tag": "blocked","settings": {}},
        {"protocol": "freedom","tag": "twotag","streamSettings": {"network": "domainsocket","dsSettings": {"path": "/usr/local/etc/v2ray/ss","abstract": true}}}
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
sed -i "s/caddy\/Caddyfile$/caddy\/Caddyfile\.json/g" /lib/systemd/system/caddy.service && systemctl daemon-reload

# caddy json config
cat <<EOF >/etc/caddy/Caddyfile.json
{
    "admin": {"disabled": true},
    "apps": {
        "tls": {"certificates": {"automate": ["$domain"]},"automation": {"policies": [{"issuer": {"challenges": {"dns": {"provider": {"name": "cloudflare","api_token": "$cloudflare_api"}}},"module": "acme"},"subjects": ["$domain"]}]}},
        "layer4": {
            "servers": {
                "example0": {
                    "listen": [":443"],
                    "routes": [
                        {
                            "match": [{"tls": {"sni": ["$domain"]}}],
                            "handle": [
                                {"handler": "tls"},
                                {
                                    "handler": "proxy",
                                    "upstreams": [{"dial": ["127.0.0.1:50000"]}]
                                }
                            ]
                        }
                    ]
                }
            }
        },
        "http": {
            "servers": {
                "srv0": {
                    "listen": [":80"],
                    "routes": [
                        {
                            "match": [{"host": ["$domain"]}],
                            "handle": [{"handler": "subroute","routes": [{"handle": [{"handler": "static_response","headers": {"Location": ["https://{http.request.host}{http.request.uri}"]},"status_code": 301}]}]}],
                            "terminal": true
                        }
                    ]
                },
                "srv1": {
                    "listen": ["127.0.0.1:50080"],
                    "routes": 
                    [
                        {
                            "handle": [{
                                "handler": "forward_proxy",
                                "hide_ip": true,
                                "hide_via": true,
                                "auth_user": "$uuid",
                                "auth_pass": "$uuid",
                                "probe_resistance": {"domain": "$uuid.com"},
                                "upstream": "socks5://$uuid:$uuid@127.0.0.1:59876"
                            }]
                        },
                        {
                            "handle": [{
                                "handler": "subroute",
                                "routes": [
                                    {
                                        "match": [{"path": ["/$vlessh2path"]}],
                                        "handle": [{
                                          "handler": "reverse_proxy",
                                          "transport": {
                                            "protocol": "http",
                                            "keep_alive": {
                                              "enabled": false
                                            },
                                            "versions": ["h2c"]
                                          },
                                          "upstreams": [{
                                            "dial": "127.0.0.1:50001"
                                          }]
                                        }],
                                        "terminal": true
                                    },
                                    {
                                        "match": [{"path": ["/$vmessh2path"]}],
                                        "handle": [{
                                          "handler": "reverse_proxy",
                                          "transport": {
                                            "protocol": "http",
                                            "keep_alive": {
                                              "enabled": false
                                            },
                                            "versions": ["h2c"]
                                          },
                                          "upstreams": [{
                                            "dial": "127.0.0.1:50002"
                                          }]
                                        }],
                                        "terminal": true
                                    }
                                ]
                            }]
                        },
                        {
                            "match": [{"host": ["$domain"]}],
                            "handle": [{
                                "handler": "file_server",
                                "root": "/usr/share/caddy"
                            }],
                            "terminal": true
                        }
                    ],
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

# systemctl service info
systemctl enable caddy v2ray && systemctl restart caddy v2ray && sleep 3 && systemctl status caddy v2ray | grep -A 2 "service"

# info
cat <<EOF >$TMPFILE
{
  "v": "2",
  "ps": "$domain-ws",
  "add": "$domain",
  "port": "443",
  "id": "$uuid",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$domain",
  "path": "$vmesswspath",
  "tls": "tls"
}
EOF
vmesswsinfo="$(echo "vmess://$(base64 -w 0 $TMPFILE)")"

cat <<EOF >$TMPFILE
{
  "v": "2",
  "ps": "$domain-h2",
  "add": "$domain",
  "port": "443",
  "id": "$uuid",
  "aid": "0",
  "net": "h2",
  "type": "none",
  "host": "$domain",
  "path": "$vmessh2path",
  "tls": "tls"
}
EOF
vmessh2info="$(echo "vmess://$(base64 -w 0 $TMPFILE)")"

cat <<EOF >$TMPFILE
$(date) $domain vless:
uuid: $uuid
wspath: $vlesspath
h2path: $vlessh2path

$(date) $domain vmess:
uuid: $uuid
tcppath: $vmesstcppath
ws+tls: $vmesswsinfo
h2+tls: $vmessh2info

$(date) $domain trojan:
password: $uuid
path: $trojanpath
nowsLink: trojan://$uuid@$domain:443#$domain-trojan

$(date) $domain shadowsocks:   
ss://$(echo -n "${ssmethod}:${uuid}" | base64 | tr "\n" " " | sed s/[[:space:]]//g | tr -- "+/=" "-_ " | sed -e 's/ *$//g')@${domain}:443?plugin=v2ray-plugin%3Bpath%3D%2F${shadowsockspath}%3Bhost%3D${domain}%3Btls#${domain}

$(date) $domain naiveproxy:
probe_resistance: $uuid.com
proxy: https://$uuid:$uuid@$domain

$(date) Visit: https://$domain
EOF

cat $TMPFILE | tee /var/log/${TMPFILE##*/} && echo && echo $(date) Info saved: /var/log/${TMPFILE##*/}
# done