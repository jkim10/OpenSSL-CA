#!/bin/bash
if [ "$#" -ne 1 ]
then
  echo "Must supply password"
  exit 1
fi
PASS=$1
cd $HOME/ca

openssl genrsa -aes256 -passout pass:$PASS -out intermediate/private/127.0.0.1.key.pem 2048

chmod 400 intermediate/private/127.0.0.1.key.pem

openssl req -passin pass:$PASS -config intermediate/openssl.cnf -key intermediate/private/127.0.0.1.key.pem\
    -subj '/CN=www.mydom.com' -new -sha256 -out intermediate/csr/127.0.0.1.csr.pem

openssl ca -batch -passin pass:$PASS -config intermediate/openssl.cnf -extensions server_cert -days 375\
    -notext -md sha256 -in intermediate/csr/127.0.0.1.csr.pem\
    -keyfile $HOME/ca/private/ca.key.pem -cert $HOME/ca/certs/ca.cert.pem -outdir ~/ca/newcerts -out intermediate/certs/127.0.0.1.cert.pem

chmod 444 intermediate/certs/127.0.0.1.cert.pem

openssl x509 -noout -text -in intermediate/certs/127.0.0.1.cert.pem

openssl verify -CAfile intermediate/certs/ca-chain.cert.pem\
    intermediate/certs/127.0.0.1.cert.pem