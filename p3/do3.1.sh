#!/usr/bin/env bash

set -e
set -x

NAME="tokmakovav"
PREFIX="$NAME-msp20"
DIR="$PREFIX-p3_1"

rm -rf $DIR
mkdir $DIR

#curl -v -x "http://localhost:3128" "http://httpbin.org/ip"
#curl -v -x "http://localhost:3128" "http://httpbin.org/get?bio=$NAME"

echo "Restarting squid with new config"
sudo cp squid.conf.3.1 /etc/squid/squid.conf
#sudo service squid restart

echo "Capturing 1"
sudo tcpdump -i any -s 0 -n -w "$DIR/$PREFIX-ua.pcapng" "(host httpbin.org or host localhost) and (port 3128 or port 80)" & 
TDPID=$!
sleep 1
curl -v -x "http://localhost:3128" "http://httpbin.org/ip"
sleep 1
sudo kill -INT "$TDPID"  # doesn't work for unknown reason
wait

echo "Capturing 2"
sudo tcpdump -i any -s 0 -n -w "$DIR/$PREFIX-acl.pcapng" "(host httpbin.org or host localhost) and (port 3128 or port 80)" &
TDPID=$!
sleep 1
curl -v -x "http://localhost:3128" "http://httpbin.org/get?bio=$NAME"
sleep 1
sudo kill -INT "$TDPID"  # doesn't work for unknown reason
wait

echo "Creating archive"
sudo chmod a=rw "$DIR/"*
zip -r "$DIR.zip" "$DIR"

echo "Done"

