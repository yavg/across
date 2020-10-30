#!/bin/sh
## 用于https://github.com/mixool/dockershc项目安装运行v2ray的测试脚本

if [[ ! -f "/workerone" ]]; then
    # install and rename
    wget -qO- https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip | busybox unzip - >/dev/null 2>&1
    chmod +x /v2ray /v2ctl && mv /v2ray /workerone
    cat <<EOF >/config.json
{
    "inbounds": 
    [
		{
			"port": 3000,"protocol": "dokodemo-door",
			"settings": {"address": "0.0.0.0","network": "tcp","followRedirect": false}
		},
        {
            "port": 1234,"listen": "127.0.0.1","protocol": "trojan",
            "settings": {"clients": [{"password":"password"}]},
            "streamSettings": {"network": "ws","wsSettings": {"path": "/trojanpass"}}
        }
    ],
    "outbounds": 
    [
        {"protocol": "freedom","tag": "direct","settings": {}},
		{"protocol": "freedom","tag": "doortrojan","settings": {"redirect": "127.0.0.1:1234"}},
        {"protocol": "blackhole","tag": "blocked","settings": {}}
    ],
    "routing": 
    {
        "rules": 
        [
			{"type": "field","domain": ["asia1.kinto.io"],"outboundTag": "doortrojan"},
            {"type": "field","outboundTag": "blocked","ip": ["geoip:private"]},
            {"type": "field","outboundTag": "block","protocol": ["bittorrent"]},
            {"type": "field","outboundTag": "blocked","domain": ["geosite:category-ads-all"]}
        ]
    }
}
EOF
else
    # start 
    /workerone -config /config.json >/dev/null 2>&1
fi
