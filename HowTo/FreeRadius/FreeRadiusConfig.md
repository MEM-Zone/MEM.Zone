openssl req -x509 -new -sha256 -newkey rsa:2048 -nodes -keyout /etc/freeradius/3.0/certs/server.pem -days 365 -out /etc/freeradius/3.0/certs/server.pem
openssl x509 -inform DER -in certificate.cer -outform PEM -out certificate.pem
openssl x509 -inform PEM -in radius.company.com.pem -outform DER -out radius.company.com.cer