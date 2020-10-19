#!/bin/bash
if [ "$#" -ne 2 ]
then
  echo "Must supply password and email"
  exit 1
fi
PASS=$1
EMAIL=$2
cd $HOME/ca

openssl genrsa -aes256 -passout pass:$PASS -out intermediate/private/$EMAIL.key.pem 2048

chmod 400 intermediate/private/$EMAIL.key.pem

openssl req -passin pass:$PASS -config intermediate/openssl.cnf -key intermediate/private/$EMAIL.key.pem\
    -subj "/CN=$EMAIL" -new -sha256 -out intermediate/csr/$EMAIL.csr.pem

openssl ca -batch -passin pass:$PASS -config intermediate/openssl.cnf -extensions usr_cert -days 375\
    -notext -md sha256 -in intermediate/csr/$EMAIL.csr.pem\
    -keyfile $HOME/ca/private/ca.key.pem -cert $HOME/ca/certs/ca.cert.pem -outdir ~/ca/newcerts -out intermediate/certs/$EMAIL.cert.pem

chmod 444 intermediate/certs/$EMAIL.cert.pem

openssl x509 -noout -text -in intermediate/certs/$EMAIL.cert.pem

openssl verify -CAfile intermediate/certs/ca-chain.cert.pem\
    intermediate/certs/$EMAIL.cert.pem