#!/usr/bin/env bash
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/nftables/nft.sh)
# Wiki: debian buster nftables https://wiki.archlinux.org/index.php/Nftables

# dependencies
command -v nft > /dev/null 2>&1 || { echo >&2 "Please install nftables： apt update && apt -t buster-backports install nftables -y"; exit 1; }

# nftables
cat <<EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet my_table {
    set blackhole {
        type ipv4_addr
        size 65535
        flags dynamic,timeout
        timeout 5d
    }
    
    chain my_input {
        type filter hook input priority 0; policy drop;
        
        iif lo accept
        ip saddr @blackhole counter set update ip saddr @blackhole counter drop
        ct state {established, related} counter accept
        ct state invalid drop
        
        ip6 nexthdr icmpv6 icmpv6 type echo-request limit rate 1/second accept
        ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, echo-reply, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
        
        ip protocol icmp icmp type echo-request limit rate 1/second accept
        ip protocol icmp icmp type { destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept
        
        tcp dport { http, https } counter accept
        udp dport { http, https } counter accept
        
        tcp flags syn tcp dport $(cat /etc/ssh/sshd_config | grep -oE "^Port [0-9]*$" | grep -oE "[0-9]*" || echo 22) meter aaameter { ip saddr ct count over 5 } add @blackhole { ip saddr } counter drop
        tcp flags syn tcp dport $(cat /etc/ssh/sshd_config | grep -oE "^Port [0-9]*$" | grep -oE "[0-9]*" || echo 22) meter bbbmeter { ip saddr limit rate over 5/hour } add @blackhole { ip saddr } counter drop
        tcp dport $(cat /etc/ssh/sshd_config | grep -oE "^Port [0-9]*$" | grep -oE "[0-9]*" || echo 22) counter accept
        
        counter comment "count dropped packets"
    }
    
    chain my_forward {
        type filter hook forward priority 0; policy accept;
        ip daddr @blackhole counter reject
        counter comment "count accepted packets"
    }
    
    chain my_output {
        type filter hook output priority 0; policy accept;
        ip daddr @blackhole counter reject
        counter comment "count accepted packets"
    }
}
EOF

systemctl enable nftables && systemctl restart nftables && nft list ruleset && systemctl status nftables 