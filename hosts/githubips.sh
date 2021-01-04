#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH
# wiki: https://github.com/521xueweihan/GitHub520

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

# get ips
URL="https://gitee.com/xueweihan/codes/6g793pm2k1hacwfbyesl464/raw?blob_name=GitHub520.yml"
wget -qO $TMPFILE $URL

# save
domains=($(cat $TMPFILE | grep -oE "^[^#]*" | awk '{print $2}' | tr "\n" " "))
for onedomain in ${domains[*]}; do sed -i "/$onedomain/d" /etc/hosts; done
cat $TMPFILE | grep -oE "^[^#]*" >>/etc/hosts