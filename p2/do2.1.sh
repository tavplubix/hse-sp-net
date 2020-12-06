#!/usr/bin/env bash

PREFIX="tokmakovav-msp20"
PASS="tokmakovav"
RESDIR="$PREFIX-p2_1"

CAKEY="$RESDIR/$PREFIX-ca.key"
CACERT="$RESDIR/$PREFIX-ca.crt"

INTRKEY="$RESDIR/$PREFIX-intr.key"
INTRCERT="$RESDIR/$PREFIX-intr.crt"

BASICKEY="$RESDIR/$PREFIX-basic.key"
BASICCERT="$RESDIR/$PREFIX-basic.crt"


mkdir "$RESDIR"

openssl genrsa -aes256 -passout "pass:$PASS" -out $CAKEY 4096
openssl req -x509 -new -key $CAKEY -passin "pass:$PASS" -out $CACERT -config ./2.1-ca.conf -days 1826

openssl genrsa -aes256 -passout "pass:$PASS" -out $INTRKEY 4096
openssl req -new -key $INTRKEY -passin "pass:$PASS" -out "$RESDIR/$PREFIX-intr.csr" -config ./2.1-intr.conf
openssl x509 -req -CA $CACERT -CAkey $CAKEY -passin "pass:$PASS" -CAcreateserial -CAserial serial -in "$RESDIR/$PREFIX-intr.csr" -extensions v3_ca -extfile ./2.1-intr.conf -out $INTRCERT -days 365

openssl genrsa -out $BASICKEY 2048
openssl req -new -key $BASICKEY -out "$RESDIR/$PREFIX-basic.csr" -config ./2.1-basic.conf
openssl x509 -req -CA $INTRCERT -CAkey $INTRKEY -passin "pass:$PASS" -CAcreateserial -CAserial serial -in "$RESDIR/$PREFIX-basic.csr" -extensions v3_ca -extfile ./2.1-basic.conf -out $BASICCERT -days 90


rm "$RESDIR/$PREFIX-intr.csr"
rm "$RESDIR/$PREFIX-basic.csr"

openssl x509 -text -noout -in $CACERT
openssl x509 -text -noout -in $INTRCERT
openssl x509 -text -noout -in $BASICCERT
openssl verify -verbose -CAfile $CACERT -untrusted $INTRCERT $BASICCERT

