#!/bin/bash
# Prepare Directory and Config File
rm -rf ~/ca
mkdir ~/ca
CA_DIR="$HOME/ca/"
cp ./openssl.cnf $CA_DIR/
cd $CA_DIR
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

#Root Key
openssl genrsa -aes256 -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

#Root Certificate
openssl req -config openssl.cnf -key private/ca.key.pem -new -x509 -days 7300 -sha256 -extensions v3_ca -out certs/ca.cert.pem
chmod 444 certs/ca.cert.pem

# Verify

openssl x509 -noout -text -in certs/ca.cert.pem