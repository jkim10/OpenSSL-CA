#!/bin/bash

if [ "$#" -ne 1 ]
then
  echo "Must supply password"
  exit 1
fi
PASS=$1
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
./createCa.sh $PASS

cd ./server
function cleanup {
  printf "\n\n${CYAN}--------------------------------------------------------------------\nEXITING AND CLEANING UP THE SERVER\n--------------------------------------------------------------------\n${NC}"
  rm server.out
  fuser -k 44330/tcp &>/dev/null
}

#########################
#    VERIFYING CERTS    #
#########################
printSection "Valid Certificate"
RES=$(openssl verify -CAfile ~/ca/intermediate/certs/ca-chain.cert.pem ~/ca/intermediate/certs/127.0.0.1.cert.pem)
echo $RES
if [[ ($RES == *"OK"*) ]]; then
  printf "${GREEN}SUCCESS: ACCEPTED CERTIFICATE\n${NC}"
else
  printf "${RED}FAILURE: CLIENT WAS NOT ACCEPTED\n${NC}"
fi
########################
printSection "Invalid Certificate"
RES=$(openssl verify -CAfile ~/ca/intermediate/certs/ca-chain.cert.pem ~/ca/intermediate/certs/invalid.cert.pem 2>&1)
echo $RES
if [[ ($RES == *"error 9 at 0 depth lookup: certificate is not yet valid"*) ]]; then
  printf "${GREEN}SUCCESS: REJECTED INVALID CERTIFICATE\n${NC}"
else
  printf "${RED}FAILURE: INVALID CERTIFICATE WAS REJECTED\n${NC}"
fi
########################
printSection "Wrong Purpose Certificate"
RES=$(openssl verify -purpose sslclient -CAfile ~/ca/certs/ca.cert.pem ~/ca/intermediate/certs/signing.cert.pem 2>&1)
echo $RES
if [[ ($RES == *"error 26 at 0 depth lookup: unsupported certificate purpose"*) ]]; then
  printf "${GREEN}SUCCESS: REJECTED WRONG PURPOSE CERTIFICATE\n${NC}"
else
  printf "${RED}FAILURE: SHOULD REJECT WRONG PURPOSE CERTIFICATE\n${NC}"
fi

#########################
# VERIFYING OVER SERVER #
#########################
#########################

printSection "Initializing Server Running in Background"
openssl s_server -pass pass:$PASS -key ~/ca/intermediate/private/127.0.0.1.key.pem \
 -Verify 1 -cert ~/ca/intermediate/certs/127.0.0.1.cert.pem \
 -CAfile ~/ca/intermediate/certs/ca-chain.cert.pem \
 -accept 44330 -ign_eof -verify_return_error -HTTP 2>server.out &

sleep .5

#####################
printSection "Connecting working client and get file"
OUTPUT=$(echo "GET /text1.txt HTTP/1.1" | openssl s_client -pass pass:$PASS -quiet -connect localhost:44330 -key ~/ca/intermediate/private/test@test.com.key.pem -verify_return_error -noservername -ign_eof -CAfile ~/ca/certs/ca.cert.pem -cert ~/ca/intermediate/certs/test@test.com.cert.pem 2>&1)
SOUTPUT=$(cat server.out)
if [[ ($OUTPUT == *"TEXT 1 TEST 123"*) && ($SOUTPUT == *"FILE:text1.txt"*) ]]; then
  printf "Server Serving: "
  tail -1  server.out
  printf "${GREEN}SUCCESS: ACCEPTED CLIENT AND RETRIEVED FILE\n${NC}"
else
  printf "${RED}FAILURE: CLIENT WAS NOT ACCEPTED AND FILE WAS NOT ACCESSED\n${NC}"
fi

#####################
printSection "Connecting client with wrong password"
OUTPUT=$(echo "GET /text1.txt HTTP/1.1" | openssl s_client -pass pass:wrongPass -quiet -connect localhost:44330 -key ~/ca/intermediate/private/test@test.com.key.pem -verify_return_error -noservername -ign_eof -CAfile ~/ca/certs/ca.cert.pem -cert ~/ca/intermediate/certs/test@test.com.cert.pem 2>&1)
if [[ ($OUTPUT == *"unable to load client certificate private key file"*)]]; then
  printf "Error Code: "
  echo $OUTPUT
  printf "${GREEN}SUCCESS: REJECTED CLIENT WITH WRONG PASSWORD AND FILE WAS NOT ACCESSED\n${NC}"
else
  printf "${RED}FAILURE: SHOULD NOT HAVE ACCEPTED CLIENT WITH WRONG PASSWORD\n${NC}"
fi

#####################

printSection "Connecting client with no certificate"
OUTPUT=$(openssl s_client -pass pass:$PASS -quiet -connect localhost:44330 -key ~/ca/intermediate/private/test@test.com.key.pem -verify_return_error -noservername -ign_eof -CAfile ~/ca/certs/ca.cert.pem 2>&1)
SOUTPUT=$(cat server.out)
if [[ ($OUTPUT == *"tlsv13 alert certificate required"*) && ($SOUTPUT == *"tls_process_client_certificate"*) ]]; then
  printf "Error Code: "
  tail -1  server.out
  printf "${GREEN}SUCCESS: REJECTED CLIENT WITH NO CERTIFICATE\n${NC}"
else
  printf "${RED}FAILURE: SHOULD REJECT CLIENT WITH NO CERTIFICATE\n${NC}"
fi

#####################
printSection "Connecting client with expired certificate"
OUTPUT=$(openssl s_client -quiet -pass pass:$PASS -connect localhost:44330 -key ~/ca/intermediate/private/expired.key.pem -verify_return_error -noservername -ign_eof -CAfile ~/ca/certs/ca.cert.pem -cert ~/ca/intermediate/certs/expired.cert.pem 2>&1)
SOUTPUT=$(cat server.out)
if [[ ($OUTPUT == *"sslv3 alert certificate expired"*) && ($SOUTPUT == *"verify error:num=10:certificate has expired"*) ]]; then
  printf "Error Code: "
  tail -3  server.out | head -1
  printf "${GREEN}SUCCESS: Rejected client with expired certificate\n${NC}"
else
  printf "${RED}FAILURE: SHOULD REJECT CLIENT WITH EXPIRED CERTIFICATE\n${NC}"
fi

#####################
printSection "Connecting client with certificate not valid yet"
OUTPUT=$(openssl s_client -quiet -pass pass:$PASS -connect localhost:44330 -key ~/ca/intermediate/private/invalid.key.pem -verify_return_error -noservername -ign_eof -CAfile ~/ca/certs/ca.cert.pem -cert ~/ca/intermediate/certs/invalid.cert.pem 2>&1)
SOUTPUT=$(cat server.out)
if [[ ($OUTPUT == *"sslv3 alert bad certificate"*) && ($SOUTPUT == *"verify error:num=9:certificate is not yet valid"*) ]]; then
  printf "Error Code: "
  tail -3  server.out | head -1
  printf "${GREEN}SUCCESS: Rejected client with certificate thats not valid yet\n${NC}"
else
  printf "${RED}FAILURE: SHOULD REJECT CERTIFICATE THATS NOT VALID YET\n${NC}"
fi

#####################
printSection "Connecting client with unsupported purpose"
OUTPUT=$(openssl s_client -quiet -pass pass:$PASS -connect localhost:44330 -key ~/ca/intermediate/private/signing.key.pem -verify_return_error -noservername -ign_eof -CAfile ~/ca/certs/ca.cert.pem -cert ~/ca/intermediate/certs/signing.cert.pem 2>&1)
SOUTPUT=$(cat server.out)
if [[ ($OUTPUT == *"sslv3 alert unsupported"*) && ($SOUTPUT == *"verify error:num=26:unsupported certificate purpose"*) ]]; then
  printf "Error Code: "
  tail -2  server.out | head -1
  printf "${GREEN}SUCCESS: REJECTED CLIENT WITH CERTIFICATE WITH UNSUPPORTED PURPOSE\n${NC}"
else
  printf "${RED}FAILURE: SHOULD REJECT CLIENT WITH CERTIFICATE WITH UNSUPPORTED PURPOSE\n${NC}"
fi

#######################
printSection "Key Value Mismatch"
OUTPUT=$(echo "GET /text1.txt HTTP/1.1" | openssl s_client -pass pass:$PASS -quiet -connect localhost:44330 -key ~/ca/intermediate/private/test@test.com.key.pem -verify_return_error -noservername -ign_eof -CAfile ~/ca/certs/ca.cert.pem -cert ~/ca/intermediate/certs/expired.cert.pem 2>&1)
SOUTPUT=$(cat server.out)
if [[ ($OUTPUT == *"key values mismatch"*) && ($SOUTPUT == *"verify error:num=26:unsupported certificate purpose"*) ]]; then
  printf "Server Serving: "
  tail -2  server.out | head -1
  printf "${GREEN}SUCCESS: ACCEPTED CLIENT AND RETRIEVED FILE\n${NC}"
else
  printf "${RED}FAILURE: CLIENT WAS NOT ACCEPTED AND FILE WAS NOT ACCESSED\n${NC}"
fi

trap cleanup EXIT