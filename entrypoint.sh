# entrypoint.sh
#!/usr/bin/env bash
echo "nameserver 8.8.8.8" > "/etc/resolv.conf" 

#exports
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/openssl/bin:/usr/local/openssl/lib
export PATH=$PATH:/usr/local/openssl
# service ssh start
# /usr/sbin/sshd -D 0.0.0.0:22
# # /bin/bash /etc/init.d/dnsmasq start -k
# while true; do sleep 2; done 

/usr/sbin/sshd -D