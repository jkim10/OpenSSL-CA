Justin Kim
jyk2149

Executables:
    ./clean.sh
        Cleans the ca folder from the home directory
    
    ./createCA.sh [Password]
        Creates the CA, IA. Then it creates and signs all the certificates
        for the client/server, and testing. Take in a password to use

        Certificates Produced (other than CA and IA):
            127.0.0.1.cert.pem     - Server Certificate
            test@test.com.cert.pem - Client Certificate
            signing.cert.pem       - Signing Certificate
            encrypt.cert.pem       - File Encryption Certificate
            expired.cert.pem       - Expired Certificate for testing
            invalid.cert.pem       - Certificate that is not valid yet

    ./createCertAndRunServer.sh
        Creates all the certs (using ./createCA) and starts a server
    
    ./runtests.sh
        Creates all the certs using dummy password "test" and runs tests



Tests:

First, you can run the automatic tests using ./runtests.sh.
It uses dummy inputs automatically so no input is needed.
Each test is separated by sections (commented in the test file)

    "Valid Server Certificate"  - Tests Server Certificate against chain cert
    "Valid Client Certificate"  - Tests Client Certificate against chain cert
    "Invalid Certificate"       - Tests certificate that is not yet valid
    "Wrong Purpose Certificate" - Tests wrong purpose certificate

    "Initializing Server Running in Background" - Runs the server to run tests against the server

    "Connecting working client and get file"       - Tests a valid certificate with the server and fetches the file from the server
    "Connecting client with wrong password"        - Tests a valid certificate with a wrong password. Should not load private key file
    "Connecting client with no certificate"        - Tests connecting a client with no certificate. Should return an error "certificate required"
    "Connecting client with expired certificate"   - Tests an expired certificate. Should return error 10
    "Connecting client with certificate not valid" - Tests an invalid certificate. Should return error 9
    "Connecting client with unsupported purpose"   - Tests a certificate with invalid keyUsage. Should return error 26
    "Connecting client with Key Value Mismatch"    - Tests a certificate that doens't match the key file
    "Connecting client with self signed certificate in certificate chain" - Tests a self signed certificate in a certificate chain

You can also run the same steps manually by runnning the "./createCertAndRunServer" command and connecting to the server using openssl s_client.
The password to use is "test". For example, this would be a sample of how to run this scenario:

    In one terminal run this command from the server directory:
        ./createCertAndRunServer 
    Then in another terminal sessions:
        echo "GET /text1.txt HTTP/1.1\r\n\r\n" | openssl s_client -pass pass:test -quiet -connect localhost:44330 -key ~/ca/intermediate/private/test@test.com.key.pem -verify_return_error -noservername -ign_eof -CAfile ~/ca/certs/ca.cert.pem -cert ~/ca/intermediate/certs/test@test.com.cert.pem

This example is tested in the ./runtest.sh but is an example on how to make a request manually.  
