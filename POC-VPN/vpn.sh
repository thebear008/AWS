echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf

sysctl -p

yum install openswan -y

cat << EOF > /etc/ipsec.d/aws.conf
conn Tunnel1
        authby=secret
        auto=start
        left=%defaultroute
        leftid=15.188.69.53
        right=35.180.80.151
        type=tunnel
        ikelifetime=8h
        keylife=1h
        phase2alg=aes128-sha1;modp1024
        ike=aes128-sha1;modp1024
        keyingtries=%forever
        keyexchange=ike
        leftsubnet=172.17.0.0/16
        rightsubnet=10.0.0.0/16
        dpddelay=10
        dpdtimeout=30
        dpdaction=restart_by_peer
EOF

echo '15.188.69.53 35.180.80.151: PSK "oLoI10o2Xp06rnzvkDHKPdzvLyYn4c1k"' > /etc/ipsec.d/aws.secrets

systemctl start ipsec
