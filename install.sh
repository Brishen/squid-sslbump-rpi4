#!/bin/bash
if [ $(id -u) -ne 0 ]; then
  printf "Script must be run with sudo\n"
  exit 1
fi
echo "" && echo "Squid SSL Bump Simplified Install" 
echo "---------------------------------"
pushd . > /dev/null
SQUID_USER=squid
SQUID_DIR=/usr/local/squid

# update and install pre-reqs
echo "" && echo "Installing Pre-Reqs..."
apt-get update
apt-get -qq -y install openssl libssl1.0-dev build-essential wget curl net-tools dnsutils tcpdump
apt-get clean

# fetch, unpack, configure and install squid 3.5.27
echo "" && echo "Building Squid..."
wget http://www.squid-cache.org/Versions/v5/squid-5.0.4.tar.gz
tar xzvf squid-5.0.4.tar.gz
cd squid-5.0.4
./configure --prefix=$SQUID_DIR --enable-ssl --with-openssl --enable-ssl-crtd --with-large-files --enable-auth --enable-icap-client
make
make install

# prep environment
echo "" && echo "Prepping Environment..."
mkdir -p $SQUID_DIR/var/lib
mkdir -p $SQUID_DIR/ssl
$SQUID_DIR/libexec/ssl_crtd -c -s $SQUID_DIR/var/lib/ssl_db
mkdir -p $SQUID_DIR/var/cache
useradd $SQUID_USER -U -b $SQUID_DIR
chown -R ${SQUID_USER}:${SQUID_USER} $SQUID_DIR
popd > /dev/null
chmod +x ./startsquid.sh
mv ./startsquid.sh $SQUID_DIR/
export PATH=$PATH:$SQUID_DIR

# set config
echo "" && echo "Updating Squid Config..."
echo "#====added config===" >> $SQUID_DIR/etc/squid.conf
echo "cache_effective_user $SQUID_USER" >> $SQUID_DIR/etc/squid.conf
echo "cache_effective_group $SQUID_USER" >> $SQUID_DIR/etc/squid.conf
echo "always_direct allow all" >> $SQUID_DIR/etc/squid.conf
echo "icap_service_failure_limit -1" >> $SQUID_DIR/etc/squid.conf
echo "ssl_bump server-first all" >> $SQUID_DIR/etc/squid.conf
echo "sslproxy_cert_error allow all" >> $SQUID_DIR/etc/squid.conf
echo "sslproxy_flags DONT_VERIFY_PEER" >> $SQUID_DIR/etc/squid.conf
sed "/^http_port 3128$/d" -i $SQUID_DIR/etc/squid.conf
sed "s/^http_access allow localnet$/http_access allow all/" -i $SQUID_DIR/etc/squid.conf
echo "http_port 3128 ssl-bump generate-host-certificates=on cert=$SQUID_DIR/ssl/localCert.crt key=$SQUID_DIR/ssl/localCert.pem" >> $SQUID_DIR/etc/squid.conf
#cat $SQUID_DIR/etc/squid.conf | grep added\ config -A1000 #fflush()

# done
echo ""
echo "Done! If there were no errors, things are ready to go."
echo "Run '$SQUID_DIR/startsquid.sh' elevated to start the proxy server."
