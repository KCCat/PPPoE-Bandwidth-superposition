#!/bin/bash

INETH=br0

start() {
    /sbin/iptables -t mangle -N BALABCE 2>/dev/null
    /sbin/iptables -t mangle -N IBALABCE 2>/dev/null
    Arr=(`ls /var/run/PPP-vP*.pid`)
    Arr=(${Arr[@]##/*/})
    Arr=(${Arr[@]%%.*})
    Mun=1
    for Ppp in ${Arr[@]}
        do
        /sbin/iptables -t mangle -A BALABCE -m statistic --mode nth --every ${#Arr[@]} --packet $((${Mun}-1)) -j MARK --set-mark $((${Mun}*0x100))/0x7F00
        /sbin/iptables -t mangle -A IBALABCE -i ${Ppp} -j CONNMARK --set-mark $((${Mun}*0x100))/0x7F00
        ip route flush table $((251-${Mun})) 2>/dev/null
        ip route add table $((251-${Mun})) default dev ${Ppp}
        ip rule add fwmark $((${Mun}*0x100))/0x7F00 table $((251-${Mun})) prio 30820
        tc qdisc add dev ${Ppp} root sfq perturb 10 2>/dev/null
        ((Mun++))
    done
    ip rule add to 192.168.128.0/24 table main prio 30000
    /sbin/iptables -t mangle -A BALABCE -j CONNMARK --save-mark --mask 0x7F00
    /sbin/iptables -t mangle -A PREROUTING -i $INETH -m state --state NEW -j BALABCE
    /sbin/iptables -t mangle -A PREROUTING ! -i $INETH -m state --state NEW -j IBALABCE
    /sbin/iptables -t mangle -A PREROUTING -i $INETH -m state --state ESTABLISHED,RELATED -j CONNMARK --restore-mark --mask 0x7F00
    echo ${Arr[@]}
}

stop() {
/sbin/iptables -t mangle -D PREROUTING -i $INETH -m state --state NEW -j BALABCE 2>/dev/null
/sbin/iptables -t mangle -D PREROUTING ! -i $INETH -m state --state NEW -j IBALABCE 2>/dev/null
/sbin/iptables -t mangle -D PREROUTING -i $INETH -m state --state ESTABLISHED,RELATED -j CONNMARK --restore-mark --mask 0x7F00 2>/dev/null
/sbin/iptables -t mangle -F BALABCE 2>/dev/null
/sbin/iptables -t mangle -F IBALABCE 2>/dev/null
ip rule del to 192.168.128.0/24 table main prio 30000
while [ $? != 2 ]
do
ip rule del from all prio 30820 2>/dev/null
done
}

case $1 in
"start")
start
;;
"stop")
stop
;;
"restart")
stop
start
;;
*)
echo "Usage $0 {start|stop|restart}"
;;
esac

exit 0

