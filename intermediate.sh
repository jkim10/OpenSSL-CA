#!/bin/bash
mkdir $HOME/ca/intermediate
cp ./intermediate-config.cnf $HOME/ca/intermediate/openssl.cnf
cd $HOME/ca/intermediate
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 1000 > $HOME/ca/intermediate/crlnumber

#Create Intermediate Key
cd $HOME/ca
openssl genrsa -aes256 -out intermediate/private/intermediate.key.pem 4096
chmod 400 intermediate/private/intermediate.key.pem

#Create Intermediate certificate
openssl req -config intermediate/openssl.cnf -new -sha256 \
-key intermediate/private/intermediate.key.pem -out intermediate/csr/intermediate.csr.pem

openssl ca -config openssl.cnf -extensions v3_intermediate_ca -keyfile ~/ca/private/ca.key.pem \
-cert ~/ca/certs/ca.cert.pem -days 3650 -notext -md sha256 -in intermediate/csr/intermediate.csr.pem -out intermediate/certs/intermediate.cert.pem


chmod 444 intermediate/certs/intermediate.cert.pem

#Verify the intermediate certificate
openssl x509 -noout -text -in intermediate/certs/intermediate.cert.pem
openssl verify -CAfile certs/ca.cert.pem intermediate/certs/intermediate.cert.pem

cat intermediate/certs/intermediate.cert.pem certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem

chmod 444 intermediate/certs/ca-chain.cert.pem
