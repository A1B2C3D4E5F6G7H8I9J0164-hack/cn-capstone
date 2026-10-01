# TLS Setup

## Project Endpoint

HTTPS is terminated by nginx on Mac 2.

- Domain: app.cn-capstone.test
- Mac 2 IP: 10.7.5.53
- HTTPS port: 8443

## Certificate

Certificate:

server.crt

Private key:

server.key

The certificate identity is:

CN=app.cn-capstone.test
DNS:app.cn-capstone.test

## nginx TLS Configuration

nginx listens on HTTPS port 8443:

listen 8443 ssl;

ssl_certificate /opt/homebrew/etc/nginx/certs/server.crt;
ssl_certificate_key /opt/homebrew/etc/nginx/certs/server.key;

## Certificate Trust

Client machines must trust the certificate.

Final HTTPS testing must use certificate validation:

curl -i https://app.cn-capstone.test:8443/

Do not use:

-k
--insecure

## Certificate Distribution

Only server.crt may be copied to client machines.

server.key must remain only on Mac 2 and must never be committed to GitHub.

## Certificate Inspection

Run:

openssl x509 -in server.crt -noout -subject -issuer -dates -ext subjectAltName

Expected identity:

CN=app.cn-capstone.test
DNS:app.cn-capstone.test

## TLS Demonstration

The project demonstrates:

ClientHello
ServerHello
Certificate
Key exchange
Finished
Encrypted application data

Wireshark is used to capture the TLS handshake and encrypted application traffic.
