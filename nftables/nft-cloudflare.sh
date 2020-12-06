#!/usr/bin/env bash
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/nftables/nft-cloudflare.sh)
# Wiki: debian buster nftables https://wiki.archlinux.org/index.php/Nftables

# dependencies
command -v nft > /dev/null 2>&1 || { echo >&2 "Please install nftables： apt update && apt install nftables -y"; exit 1; }

# nftables
cat <<EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

# List all IPs and IP ranges of your traffic filtering proxy source. https://www.cloudflare.com/ips/
define SAFE_TRAFFIC_IPS = {
    173.245.48.0/20,
    103.21.244.0/22,
    103.22.200.0/22,
    103.31.4.0/22,
    141.101.64.0/18,
    108.162.192.0/18,
    190.93.240.0/20,
    188.114.96.0/20,
    197.234.240.0/22,
    198.41.128.0/17,
    162.158.0.0/15,
    104.16.0.0/12,
    172.64.0.0/13,
    131.0.72.0/22
}

table inet my_table {
    chain my_input {
        type filter hook input priority 0; policy drop;
        
        ip6 nexthdr icmpv6 icmpv6 type echo-request limit rate 1/second accept
        ip6 nexthdr icmpv6 icmpv6 type echo-request counter drop
        
        ip protocol icmp icmp type echo-request limit rate 1/second accept
        ip protocol icmp icmp type echo-request counter drop
        
        ct state {established, related} counter accept
        ct state invalid drop
        
        ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, echo-reply, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
        ip protocol icmp icmp type { destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept
        
        iif lo accept

        tcp dport { http, https } ip saddr \$SAFE_TRAFFIC_IPS accept
        udp dport { http, https } ip saddr \$SAFE_TRAFFIC_IPS accept
        tcp dport $(cat /etc/ssh/sshd_config | grep -oE "^Port [0-9]*$" | grep -oE "[0-9]*" || echo 22) ct state new limit rate 5/minute counter accept
        
        counter comment "count dropped packets"
    }
    
    chain my_forward {
        type filter hook forward priority 0; policy accept;
        counter comment "count accepted packets"
    }
    
    chain my_output {
        type filter hook output priority 0; policy accept;
        counter comment "count accepted packets"
    }
}
EOF

systemctl enable nftables && systemctl restart nftables && nft list ruleset && systemctl status nftables
