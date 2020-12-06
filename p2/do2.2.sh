#!/usr/bin/env bash

PREFIX="tokmakovav-msp20"
PASS="tokmakovav"
PREVDIR="$PREFIX-p2_1"
RESDIR="$PREFIX-p2_2"

CAKEY="$PREVDIR/$PREFIX-ca.key"
CACERT="$PREVDIR/$PREFIX-ca.crt"

INTRKEY="$PREVDIR/$PREFIX-intr.key"
INTRCERT="$PREVDIR/$PREFIX-intr.crt"

VALIDKEY="$RESDIR/$PREFIX-crl-valid.key"
VALIDCERT="$RESDIR/$PREFIX-crl-valid.crt"

REVOKEDKEY="$RESDIR/$PREFIX-crl-revoked.key"
REVOKEDCERT="$RESDIR/$PREFIX-crl-revoked.crt"

CRL="$RESDIR/$PREFIX.crl"
CHAIN="$RESDIR/$PREFIX-ca.crt"

DBDIR="./demoCA"
DBIDX="$DBDIR/index.txt"

mkdir "$RESDIR"
mkdir $DBDIR
touch $DBIDX
touch "$DBIDX.attr"

openssl genrsa -out $VALIDKEY 2048
openssl req -new -key $VALIDKEY -out "$RESDIR/$PREFIX-crl-valid.csr" -config ./2.2-valid.conf
openssl x509 -req -CA $INTRCERT -CAkey $INTRKEY -passin "pass:$PASS" -CAcreateserial -CAserial serial -in "$RESDIR/$PREFIX-crl-valid.csr" -extensions v3_ca -extfile ./2.2-valid.conf -out $VALIDCERT -days 90

openssl genrsa -out $REVOKEDKEY 2048
openssl req -new -key $REVOKEDKEY -out "$RESDIR/$PREFIX-crl-revoked.csr" -config ./2.2-revoked.conf
openssl x509 -req -CA $INTRCERT -CAkey $INTRKEY -passin "pass:$PASS" -CAcreateserial -CAserial serial -in "$RESDIR/$PREFIX-crl-revoked.csr" -extensions v3_ca -extfile ./2.2-revoked.conf -out $REVOKEDCERT -days 90


rm "$RESDIR/$PREFIX-crl-valid.csr"
rm "$RESDIR/$PREFIX-crl-revoked.csr"

openssl x509 -text -noout -in $VALIDCERT
openssl x509 -text -noout -in $REVOKEDCERT
#openssl x509 -text -noout -in $BASICCERT
openssl verify -verbose -CAfile $CACERT -untrusted $INTRCERT $VALIDCERT
openssl verify -verbose -CAfile $CACERT -untrusted $INTRCERT $REVOKEDCERT


openssl ca -config ./2.2-crl.conf -passin "pass:$PASS" -gencrl -out $CRL
openssl crl -text -noout -in $CRL
openssl ca -config ./2.2-crl.conf -passin "pass:$PASS" -revoke $REVOKEDCERT
openssl ca -config ./2.2-crl.conf -passin "pass:$PASS" -gencrl -out $CRL
openssl crl -text -noout -in $CRL

openssl verify -verbose -crl_check -CRLfile $CRL -CAfile $CACERT -untrusted $INTRCERT $VALIDCERT
openssl verify -verbose -crl_check -CRLfile $CRL -CAfile $CACERT -untrusted $INTRCERT $REVOKEDCERT

cat $CACERT $INTRCERT > $CHAIN
openssl verify -verbose -crl_check -CRLfile $CRL -CAfile $CHAIN $VALIDCERT
openssl verify -verbose -crl_check -CRLfile $CRL -CAfile $CHAIN $REVOKEDCERT


