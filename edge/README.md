# Mac 2 Edge Server

## Role

Mac 2 is the edge server for the CN Private Network Platform.

It acts as:

- HTTPS termination point
- Reverse proxy
- Round-robin load balancer
- Single public application entry point

## Network Details

- Hostname: cn-edge
- IP address: 10.7.5.53
- Interface: en0
- HTTPS port: 8443
- Application domain: app.cn-capstone.test

## Request Flow

Client
-> DNS resolution through Mac 1
-> app.cn-capstone.test resolves to 10.7.5.53
-> nginx on Mac 2:8443
-> Backend A or Backend B

## Backend Servers

### Backend A

- Host: Mac 3
- IP: 10.7.22.10
- Port: 3001

### Backend B

- Host: Mac 4
- IP: 10.7.7.25
- Port: 3002

## Load Balancing

nginx uses an upstream group named:

cn_backends

The upstream contains:

10.7.22.10:3001
10.7.7.25:3002

Requests are distributed using nginx round-robin behavior.

The response header:

X-Backend: A

or:

X-Backend: B

is used to demonstrate which backend handled each request.

## HTTPS

nginx terminates TLS on:

8443

The server name is:

app.cn-capstone.test

The certificate is stored locally on Mac 2 and is trusted by client machines for the demonstration.

## Reverse Proxy

Clients do not connect directly to ports 3001 or 3002 during the normal application flow.

The client connects to:

https://app.cn-capstone.test:8443

nginx forwards the request to one of the backend servers.

## Configuration Test

Validate nginx configuration with:

nginx -t

## Service

Homebrew nginx can be managed with:

brew services start nginx
brew services stop nginx
brew services restart nginx

## Verification

Check HTTPS:

curl -i https://app.cn-capstone.test:8443/api/status

Check repeated load-balanced responses:

for i in {1..20}; do
  curl -s -D - https://app.cn-capstone.test:8443/api/status -o /dev/null | grep X-Backend
done

Expected output contains responses from both:

X-Backend: A
X-Backend: B
