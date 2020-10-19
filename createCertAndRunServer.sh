#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
function printSection(){
    printf "${YELLOW}--------------------------------------------------------------------\n$1\n--------------------------------------------------------------------\n${NC}"
}
fuser -k 44330/tcp &>/dev/null
printSection "Creating Certificates"
cleanup
./clean.sh
./createCa.sh test
cd ./server
openssl s_server -pass pass:test -key ~/ca/intermediate/private/127.0.0.1.key.pem \
 -Verify 1 -cert ~/ca/intermediate/certs/127.0.0.1.cert.pem \
 -CAfile ~/ca/intermediate/certs/ca-chain.cert.pem \
 -accept 44330 -ign_eof -verify_return_error -HTTP