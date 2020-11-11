#!/usr/bin/env bash

PREFIX="tokmakovav-msp20"
PASS="tokmakovav"
PREVDIR="$PREFIX-p2_1"
RESDIR="$PREFIX-p2_3"

CAKEY="$PREVDIR/$PREFIX-ca.key"
CACERT="$PREVDIR/$PREFIX-ca.crt"

INTRKEY="$PREVDIR/$PREFIX-intr.key"
INTRCERT="$PREVDIR/$PREFIX-intr.crt"


OCSPKEY="$RESDIR/$PREFIX-ocsp-resp.key"
OCSPCERT="$RESDIR/$PREFIX-ocsp-resp.crt"
OCSPKEYTMP="$PREFIX-ocsp-resp.key.tmp" # not encrypted key to run OCSP server

VALIDKEY="$RESDIR/$PREFIX-ocsp-valid.key"
VALIDCERT="$RESDIR/$PREFIX-ocsp-valid.crt"

REVOKEDKEY="$RESDIR/$PREFIX-ocsp-revoked.key"
REVOKEDCERT="$RESDIR/$PREFIX-ocsp-revoked.crt"

CHAIN="$RESDIR/$PREFIX-ca.crt"

DBDIR="./demoCA"
DBIDX="$DBDIR/index2.3.txt"

mkdir "$RESDIR"
mkdir $DBDIR
rm $DBIDX
touch $DBIDX
touch "$DBIDX.attr"

echo "Create OCSP key and cert"
openssl genrsa -aes256 -passout "pass:$PASS" -out $OCSPKEY 4096
openssl req -new -key $OCSPKEY -passin "pass:$PASS" -out "$RESDIR/$PREFIX-ocsp-resp.csr" -config ./2.3-ocsp.conf
openssl x509 -req -CA $INTRCERT -CAkey $INTRKEY -passin "pass:$PASS" -CAcreateserial -CAserial serial -in "$RESDIR/$PREFIX-ocsp-resp.csr" -extensions v3_ca -extfile ./2.3-ocsp.conf -out $OCSPCERT -days 365

echo "Create 'valid' cert"
openssl genrsa -out $VALIDKEY 2048
openssl req -new -key $VALIDKEY -out "$RESDIR/$PREFIX-ocsp-valid.csr" -config ./2.3-valid.conf
openssl x509 -req -CA $INTRCERT -CAkey $INTRKEY -passin "pass:$PASS" -CAcreateserial -CAserial serial -in "$RESDIR/$PREFIX-ocsp-valid.csr" -extensions v3_ca -extfile ./2.3-valid.conf -out $VALIDCERT -days 90

echo "Create 'revoked' cert"
openssl genrsa -out $REVOKEDKEY 2048
openssl req -new -key $REVOKEDKEY -out "$RESDIR/$PREFIX-ocsp-revoked.csr" -config ./2.3-revoked.conf
openssl x509 -req -CA $INTRCERT -CAkey $INTRKEY -passin "pass:$PASS" -CAcreateserial -CAserial serial -in "$RESDIR/$PREFIX-ocsp-revoked.csr" -extensions v3_ca -extfile ./2.3-revoked.conf -out $REVOKEDCERT -days 90

echo "Remove csr's"
rm "$RESDIR/$PREFIX-ocsp-resp.csr"
rm "$RESDIR/$PREFIX-ocsp-valid.csr"
rm "$RESDIR/$PREFIX-ocsp-revoked.csr"

echo -e "\n\nPrint certs\n"
echo $OCSPCERT && openssl x509 -text -noout -in $OCSPCERT
echo $VALIDCERT && openssl x509 -text -noout -in $VALIDCERT
echo $REVOKEDCERT && openssl x509 -text -noout -in $REVOKEDCERT
openssl verify -verbose -CAfile $CACERT -untrusted $INTRCERT $OCSPCERT
openssl verify -verbose -CAfile $CACERT -untrusted $INTRCERT $VALIDCERT
openssl verify -verbose -CAfile $CACERT -untrusted $INTRCERT $REVOKEDCERT

cat $CACERT $INTRCERT > $CHAIN

echo "Create index.txt"
# dirty hack: add $VALIDCERT to $DBIDX file
openssl ca -config 2.3-ca.conf -passin "pass:$PASS" -revoke $VALIDCERT
cat $DBIDX | sed "s|R\t|V\t|" | sed "s|\tunknown\t|\t$VALIDCERT\t|" | sed 's|Z\t[0-9]*Z\t|Z\t\t|'> "$DBIDX.tmp"
mv "$DBIDX.tmp" $DBIDX
cat $DBIDX
openssl ca -config 2.3-ca.conf -passin "pass:$PASS" -revoke $REVOKEDCERT

openssl rsa -in $OCSPKEY -passin "pass:$PASS" -out $OCSPKEYTMP

echo "Run OCSP server"
timeout 5 openssl ocsp -port 2560 -index $DBIDX -CA $CHAIN -rkey $OCSPKEYTMP -rsigner $OCSPCERT &
sleep 1
openssl ocsp -url http://ocsp.tokmakovav.ru:2560 -CAfile $CHAIN -issuer $INTRCERT -cert $VALIDCERT
openssl ocsp -url http://ocsp.tokmakovav.ru:2560 -CAfile $CHAIN -issuer $INTRCERT -cert $REVOKEDCERT

echo -e "Command to run OCSP:\n    openssl ocsp -port 2560 -index $DBIDX -CA $CHAIN -rkey $OCSPKEYTMP -rsigner $OCSPCERT"
echo -e "Command to run nginx:\n    docker run -p 443:443 -v `pwd`/nginx.conf:/etc/nginx/nginx.conf:ro -v `pwd`/$RESDIR:/$RESDIR:ro nginx"
echo -e "Command to check valid cert:\n    curl --cacert $CHAIN 'https://ocsp.valid.tokmakovav.ru/' -v"
echo -e "Command to check revoked cert (does not work, use Firefox instead, LOL):\n    curl --cacert $CHAIN 'https://ocsp.revoked.tokmakovav.ru/' -v"
wait


