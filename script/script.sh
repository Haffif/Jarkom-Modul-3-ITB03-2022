#!/bin/env bash

# Ostania
if [[ $HOSTNAME = "Ostania" ]]; then
        apt-get update
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE -s 10.46.0.0/16
        apt-get install isc-dhcp-relay -y

        echo "
        # What servers should the DHCP relay forward requests to?
        SERVERS=\"10.46.2.4\"
        # On what interfaces should the DHCP relay (dhrelay) serve DHCP requests?
        INTERFACES=\"eth1 eth3 eth2\"
        # Additional options that are passed to the DHCP relay daemon?
        OPTIONS=\"\"
        " > /etc/default/isc-dhcp-relay

        service isc-dhcp-relay restart
       
# WISE
elif [[ $HOSTNAME = "WISE" ]]; then
        echo "nameserver 192.168.122.1" > /etc/resolv.conf
        apt-get update
        apt-get install bind9 -y
        apt-get install apache2 -y

        echo '
options {
        directory "/var/cache/bind";
        forwarders {
                192.168.122.1;
        };
        allow-query{any;};
        auth-nxdomain no;
        listen-on-v6 { any; };
};
' > /etc/bind/named.conf.options

        echo "
zone \"loid-work.com\" {
        type master;
        file \"/etc/bind/jarkom/loid-work.com\";
};
zone \"franky-work.com\" {
        type master;
        file \"/etc/bind/jarkom/franky-work.com\";
};
"> /etc/bind/named.conf.local

        mkdir -p  /etc/bind/jarkom

        echo "
;
; BIND data file for local loopback interface
;
\$TTL    604800
@       IN      SOA     franky-work.com. root.franky-work.com. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@               IN      NS      franky-work.com.
@               IN      A       10.46.2.2     ; IP WISE
www             IN      CNAME   franky-work.com.
" > /etc/bind/jarkom/franky-work.com

        echo "
;
; BIND data file for local loopback interface
;
\$TTL    604800
@       IN      SOA     loid-work.com. root.loid-work.com. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      loid-work.com.
@       IN      A       10.46.2.2     ; IP WISE
www     IN      CNAME   loid-work.com.
" > /etc/bind/jarkom/loid-work.com

        echo '
<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ServerName loid-work.com
 
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
' > /etc/apache2/sites-available/loid-work.com.conf

        echo '
<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ServerName franky-work.com
 
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
' > /etc/apache2/sites-available/franky-work.com.conf

        service apache2 start
        a2ensite loid-work.com.conf
        a2ensite franky-work.com.conf
        service apache2 restart

        service bind9 restart

# Westalis
elif [[ $HOSTNAME = "Westalis" ]]; then
        echo "nameserver 192.168.122.1" > /etc/resolv.conf
        apt-get update
        apt-get install isc-dhcp-server -y

        echo "
        # On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
        # Separate multiple interfaces with spaces, e.g. \"eth0 eth1\".
        INTERFACES=\"eth0\"
        " > /etc/default/isc-dhcp-server

        echo '
ddns-update-style none;

option domain-name "example.org";
option domain-name-servers ns1.example.org, ns2.example.org;

default-lease-time 600;
max-lease-time 7200;

log-facility local7;

subnet 10.46.2.0 netmask 255.255.255.0 {
}

subnet 10.46.1.0 netmask 255.255.255.0 {
    range  10.46.1.50 10.46.1.88;
    range  10.46.1.120 10.46.1.155;
    option routers 10.46.1.1;
    option broadcast-address 10.46.1.255;
    option domain-name-servers 10.46.2.2;
    default-lease-time 300;
    max-lease-time 6900;
}

subnet 10.46.3.0 netmask 255.255.255.0 {
    range  10.46.3.10 10.46.3.30;
    range  10.46.3.60 10.46.3.85;
    option routers 10.46.3.1;
    option broadcast-address 10.46.3.255;
    option domain-name-servers 10.46.2.2;
    default-lease-time 600;
    max-lease-time 6900;
}

host Eden {
    hardware ethernet 4e:af:14:af:af:a3;
    fixed-address 10.46.3.13;
}
' > /etc/dhcp/dhcpd.conf

        service isc-dhcp-server restart

# Berlint
elif [[ $HOSTNAME = "Berlint" ]]; then
        echo "nameserver 192.168.122.1" > /etc/resolv.conf
        apt-get update
        apt-get install squid -y

        echo '
acl WORKTIME time MTWHF 08:00-17:00
acl WEEKEND time SA 00:00-23:59
' > /etc/squid/acl-time.conf

        echo '
loid-work.com
franky-work.com
' > /etc/squid/work-sites.acl

        echo '
acl WORKSITE dstdomain "/etc/squid/work-sites.acl"
' > /etc/squid/acl-site.conf

        echo '
acl GOODPORT port 443
acl CONNECT method CONNECT
' > /etc/squid/acl-port.conf

        echo '
delay_pools 1
delay_class 1 1
delay_access 1 allow WEEKEND
delay_parameters 1 16000/16000
' > /etc/squid/acl-banwidth.conf

        echo '
include /etc/squid/acl-time.conf
include /etc/squid/acl-site.conf
include /etc/squid/acl-port.conf
include /etc/squid/acl-banwidth.conf

http_port 8080
dns_nameservers 10.46.2.2

http_access allow WORKSITE WORKTIME
http_access deny !GOODPORT
http_access deny CONNECT !GOODPORT
http_access allow !WORKTIME
#http_access deny WORKSITE WEEKEND
http_access deny all
visible_hostname Berlint
' > /etc/squid/squid.conf

        service squid restart

# Eden
elif [[ $HOSTNAME = "Eden" ]]; then
        apt-get update
        apt-get install apache2 -y
        service apache2 start
        apt-get install php -y
        apt-get install libapache2-mod-php7.0 -y
        apt-get install ca-certificates openssl -y
        apt-get install git -y
        apt-get install unzip -y
        apt-get install wget -y
        apt-get install lynx -y
        apt-get install speedtest-cli -y

        export http_proxy="http://10.46.2.3:8080"

# SSS
elif [[ $HOSTNAME = "SSS" ]]; then
        apt-get update
        apt-get install speedtest-cli -y
        apt-get install ca-certificates openssl -y
        apt-get install dnsutils -y
        apt-get install lynx -y

        export http_proxy="http://10.46.2.3:8080"
# Garden
elif [[ $HOSTNAME = "Garden" ]]; then
        apt-get update
        apt-get install speedtest-cli -y
        apt-get install ca-certificates openssl -y
        apt-get install dnsutils -y
        apt-get install lynx -y

        export http_proxy="http://10.46.2.3:8080"
# KemonoPark
elif [[ $HOSTNAME = "KemonoPark" ]]; then
        apt-get update
        apt-get install dnsutils -y
        apt-get install lynx -y
# NewstonCastle
elif [[ $HOSTNAME = "NewstonCastle" ]]; then
        apt-get update
        apt-get install dnsutils -y
        apt-get install lynx -y

fi