#!/usr/bin/env bash
# Wiki: https://github.com/tindy2013/subconverter
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/subconverter/run.sh) my.domain.com
# Uninstall: apt purge caddy -y; systemctl stop subconverter; systemctl disable subconverter; rm -rf /etc/systemd/system/subconverter.service /usr/bin/subconverter

########
[[ $# != 1 ]] && echo Err  !!! Useage: bash this_script.sh my.domain.com && exit 1 || domain="$1"
########

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

# caddy install 
caddyURL="$(wget -qO-  https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_amd64\.deb" | cut -f4 -d\" | head -n1)"
wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE

cat <<EOF >/etc/caddy/Caddyfile
$domain
root * /usr/share/caddy
file_server
reverse_proxy http://127.0.0.1:25500
EOF

# subconverter
URL="$(wget -qO- https://api.github.com/repos/tindy2013/subconverter/releases/latest | grep -E "browser_download_url.*linux64.tar.gz" | cut -f4 -d\")"
rm -rf /root/subconverter /root/subconverter_linux64.tar.gz
wget $URL && tar -zxf subconverter_linux64.tar.gz && sed -i "s/listen=0.0.0.0/listen=127.0.0.1/g" /root/subconverter/pref.ini && rm -rf /root/subconverter_linux64.tar.gz
chmod +x /root/subconverter/subconverter

cat <<EOF > /etc/systemd/system/subconverter.service
[Unit]
Description=subconverter
[Service]
ExecStart=/root/subconverter/subconverter
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

# systemctl
systemctl enable caddy subconverter && systemctl daemon-reload && systemctl restart caddy subconverter && sleep 3 && systemctl status caddy subconverter | grep -A 2 "service"

# info
echo $(date) Visit: https://$domain
