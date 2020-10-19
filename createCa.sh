#!/bin/bash
# Prepare Directory and Config File
if [ "$#" -ne 1 ]
then
  echo "Must supply password"
  exit 1
fi
PASS=$1
SOURCEDIR=$(pwd)
rm -rf ~/ca
mkdir ~/ca
mkdir $HOME/ca/intermediate
CA_DIR="$HOME/ca/"
cp ./configs/openssl.cnf $CA_DIR/
cp ./configs/intermediate-config.cnf $HOME/ca/intermediate/openssl.cnf
cd $CA_DIR
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

#Root Key
openssl genrsa -aes256 -passout pass:$PASS  -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

#Root Certificate
openssl req -config openssl.cnf -passin pass:$PASS -key private/ca.key.pem -new -x509 -days 7300 -sha256 -extensions v3_ca -out certs/ca.cert.pem
chmod 444 certs/ca.cert.pem

# Verify

openssl x509 -noout -text -in certs/ca.cert.pem

#Intermediate
cd $HOME/ca/intermediate
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 1000 > $HOME/ca/intermediate/crlnumber

#Create Intermediate Key
cd $HOME/ca
openssl genrsa -aes256 -passout pass:$PASS -out intermediate/private/intermediate.key.pem 4096
chmod 400 intermediate/private/intermediate.key.pem

#Create Intermediate certificate
openssl req -config intermediate/openssl.cnf -passin pass:$PASS -new -sha256 \
-key intermediate/private/intermediate.key.pem -out intermediate/csr/intermediate.csr.pem

openssl ca -batch -config openssl.cnf -passin pass:$PASS -extensions v3_intermediate_ca -keyfile $HOME/ca/private/ca.key.pem \
-cert $HOME/ca/certs/ca.cert.pem -outdir ~/ca/newcerts -days 3650 -notext -md sha256 \
-in intermediate/csr/intermediate.csr.pem -out intermediate/certs/intermediate.cert.pem


chmod 444 intermediate/certs/intermediate.cert.pem

#Verify the intermediate certificate
openssl x509 -noout -text -in intermediate/certs/intermediate.cert.pem
openssl verify -CAfile certs/ca.cert.pem intermediate/certs/intermediate.cert.pem

cat intermediate/certs/intermediate.cert.pem certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem

chmod 444 intermediate/certs/ca-chain.cert.pem

#Creating Server Cert
$SOURCEDIR/server/issue_server.sh $PASS
#Creating Client Cert (using test email)
$SOURCEDIR/client/issue_client.sh $PASS test@test.com

#Creating Sign Cert
openssl genrsa -aes256 -passout pass:$PASS -out intermediate/private/signing.key.pem 2048

chmod 400 intermediate/private/signing.key.pem

openssl req -passin pass:$PASS -config intermediate/openssl.cnf -key intermediate/private/signing.key.pem\
    -subj "/CN=signing" -new -sha256 -out intermediate/csr/signing.csr.pem

openssl ca -batch -passin pass:$PASS -config intermediate/openssl.cnf -extensions sign_cert -days 3650\
    -notext -md sha256 -in intermediate/csr/signing.csr.pem\
    -keyfile $HOME/ca/private/ca.key.pem -cert $HOME/ca/certs/ca.cert.pem -outdir ~/ca/newcerts -out intermediate/certs/signing.cert.pem

chmod 444 intermediate/certs/signing.cert.pem

#Creating Expired Cert for testing

openssl genrsa -aes256 -passout pass:$PASS -out intermediate/private/expired.key.pem 2048

chmod 400 intermediate/private/expired.key.pem

openssl req -passin pass:$PASS -config intermediate/openssl.cnf -key intermediate/private/expired.key.pem\
    -subj "/CN=expired" -new -sha256 -out intermediate/csr/expired.csr.pem

openssl ca -batch -passin pass:$PASS -config intermediate/openssl.cnf -extensions usr_cert -startdate 19990101000000Z -enddate 19990101000001Z\
    -notext -md sha256 -in intermediate/csr/expired.csr.pem\
    -keyfile $HOME/ca/private/ca.key.pem -cert $HOME/ca/certs/ca.cert.pem -outdir ~/ca/newcerts -out intermediate/certs/expired.cert.pem

chmod 444 intermediate/certs/expired.cert.pem

#Creating certificate that is not valid yet
openssl genrsa -aes256 -passout pass:$PASS -out intermediate/private/invalid.key.pem 2048

chmod 400 intermediate/private/invalid.key.pem

openssl req -passin pass:$PASS -config intermediate/openssl.cnf -key intermediate/private/invalid.key.pem\
    -subj "/CN=invalid" -new -sha256 -out intermediate/csr/invalid.csr.pem

openssl ca -batch -passin pass:$PASS -config intermediate/openssl.cnf -extensions usr_cert -startdate 20240101000000Z -enddate 20240101000001Z\
    -notext -md sha256 -in intermediate/csr/invalid.csr.pem\
    -keyfile $HOME/ca/private/ca.key.pem -cert $HOME/ca/certs/ca.cert.pem -outdir ~/ca/newcerts -out intermediate/certs/invalid.cert.pem

chmod 444 intermediate/certs/invalid.cert.pem

#Creating dummy cert and key
touch intermediate/certs/wrongIssuer.cert.pem
touch intermediate/private/wrongIssuer.key.pem