#!/usr/bin/env bash

set -e
set -x

NAME="tokmakovav"
PREFIX="$NAME-msp20"
DIR="$PREFIX-p3_2"

CACERT="../archives/tokmakovav-msp20-ca.crt"
CAKEY="../archives/tokmakovav-msp20-ca.key"
PASS="tokmakovav"

CA="$DIR/$PREFIX-ca.crt"
CERT="$DIR/$PREFIX-bump.crt"
KEY="$DIR/$PREFIX-bump.key"

rm -rf $DIR
mkdir $DIR

echo "Generating keys"
cp "$CACERT" "$CA"
openssl genrsa -out $KEY 4096
openssl req -new -key $KEY -out "$PREFIX-bump.csr" -config ./cert.conf
openssl x509 -req -CA $CACERT -CAkey $CAKEY -passin "pass:$PASS" -CAcreateserial -CAserial serial -in "$PREFIX-bump.csr" -extensions v3_ca -extfile ./cert.conf -out $CERT -days 365
rm "$PREFIX-bump.csr"
openssl x509 -text -noout -in $CERT
cat $CERT $KEY >> squid.pem

echo "Restarting squid with new config"
sudo service squid stop
sudo cp squid.pem /etc/squid/squid.pem
sudo cp squid.conf.3.2 /etc/squid/squid.conf
sudo rm -rf /var/lib/ssl_db
sudo /usr/lib/squid/ssl_crtd -c -s /var/lib/ssl_db
sudo service squid start


echo "Capturing 1"
sudo tcpdump -i any -s 0 -n -w "$DIR/$PREFIX-acl.pcapng" "(host ident.me or host httpbin.org or host localhost) and (port 3128 or port 443)" & 
TDPID=$!
sleep 1
SSLKEYLOGFILE="$DIR/$PREFIX-acl.log" curl -v -x "http://localhost:3128" "https://ident.me/" || echo "Connection terminated (as expected)"
sleep 1
SSLKEYLOGFILE="$DIR/$PREFIX-acl.log" curl -v -x "http://localhost:3128" "https://httpbin.org/get?bio=$NAME"
sleep 1
sudo kill -INT "$TDPID"  # doesn't work for unknown reason
wait


echo "Restarting squid with new config"
sudo service squid stop
sudo cp squid.pem /etc/squid/squid.pem
sudo cp squid.conf.3.2.2 /etc/squid/squid.conf
sudo rm -rf /var/lib/ssl_db
sudo /usr/lib/squid/ssl_crtd -c -s /var/lib/ssl_db     
sudo service squid start

echo "Capturing 2"
sudo tcpdump -i any -s 0 -n -w "$DIR/$PREFIX-bump.pcapng" "(host httpbin.org or host localhost) and (port 3128 or port 443)" &
TDPID=$!
sleep 1
SSLKEYLOGFILE="$DIR/$PREFIX-bump.log" curl -v --cacert $CA -x "http://localhost:3128" "https://httpbin.org/get?bio=$NAME"
sleep 1
sudo kill -INT "$TDPID"  # doesn't work for unknown reason
wait

echo "Creating archive"
sudo chmod a=rw "$DIR/"*
zip -r "$DIR.zip" "$DIR"

echo "Done"

