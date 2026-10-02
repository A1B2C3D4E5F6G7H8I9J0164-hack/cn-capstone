# Cluster Setup and Deployment Guide

## Computer Networks Capstone Project

### Core Principle
"The application stays simple; the network is the project."

This guide walks through configuring each of the four physical macOS laptops from a fresh state.

---

## 1. Prerequisites and Common Dependencies

Ensure all four machines are connected to the same Wi-Fi / LAN network and have Homebrew installed.

```bash
# Verify Homebrew installation
brew --version

# Verify Python 3
python3 --version

# Verify curl and dig
curl --version
dig -v
```

---

## 2. Mac 1 Setup: Private DNS Server (Aditya Rana)

### Step 2.1: Install and Configure dnsmasq
```bash
# Install dnsmasq via Homebrew
brew install dnsmasq

# Copy base configuration
sudo cp dns/dnsmasq.conf.example /opt/homebrew/etc/dnsmasq.conf

# Create configuration directory for project zones
sudo mkdir -p /opt/homebrew/etc/dnsmasq.d

# Copy project domain zone mappings
sudo cp dns/project.conf.example /opt/homebrew/etc/dnsmasq.d/project.conf
```

### Step 2.2: Start dnsmasq Service
Because port 53 is a privileged port (< 1024), dnsmasq must be run with root permissions:
```bash
# Start dnsmasq as a root service
sudo brew services start dnsmasq
```

### Step 2.3: Verify Local DNS Resolution
```bash
# Query the local dnsmasq service
dig @127.0.0.1 app.cn-capstone.test +short
# Expected output: 10.7.5.53
```

---

## 3. Mac 2 Setup: Edge Proxy and Load Balancer (Krishna)

### Step 3.1: Install Nginx and OpenSSL
```bash
brew install nginx openssl
```

### Step 3.2: Generate TLS Private Key and SAN Certificate
```bash
# Create directory for certificates
mkdir -p /opt/homebrew/etc/nginx/certs

# Generate 2048-bit RSA private key and self-signed certificate with SAN extension
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -config tls/openssl.cnf.example \
  -keyout /opt/homebrew/etc/nginx/certs/server.key \
  -out /opt/homebrew/etc/nginx/certs/server.crt

# Verify certificate contents and SAN identity
openssl x509 -in /opt/homebrew/etc/nginx/certs/server.crt -noout -subject -dates -ext subjectAltName
```

### Step 3.3: Configure and Launch Nginx
```bash
# Copy nginx configuration
cp edge/nginx.conf.example /opt/homebrew/etc/nginx/nginx.conf

# Validate nginx configuration syntax
nginx -t

# Start or restart nginx service
brew services restart nginx
```

---

## 4. Mac 3 Setup: Backend Server A (Rachit Gupta)

### Step 4.1: Launch Backend Server A
```bash
cd backend-a
python3 server.py
```
*The server binds to `0.0.0.0:3001` and outputs:*
```
Backend A running on http://0.0.0.0:3001
Machine: Mac 3 | Member: Rachit Gupta | Bound to: 0.0.0.0:3001
```

### Step 4.2: Verify Local Reachability
```bash
curl -i http://localhost:3001/api/status
```

---

## 5. Mac 4 Setup: Backend Server B and Client Setup (Saumya Mishra)

### Step 5.1: Launch Backend Server B
```bash
cd backend-b
python3 server.py
```
*The server binds to `0.0.0.0:3002` and outputs:*
```
Backend B running on http://0.0.0.0:3002
Machine: Mac 4 | Member: Saumya Mishra | Bound to: 0.0.0.0:3002
```

### Step 5.2: Configure DNS Resolver on Client Machines
On Mac 4 (and Mac 2/3 when acting as test clients):
```bash
# Configure system DNS to query Mac 1 (replace 10.7.x.x with Mac 1 IP)
sudo networksetup -setdnsservers Wi-Fi 10.7.x.x

# Verify DNS resolution of project domain
dig app.cn-capstone.test +short
# Expected output: 10.7.5.53
```

### Step 5.3: Trust the Project Certificate
Copy `server.crt` from Mac 2 to the client machine:
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain server.crt
```

---

## 6. End-to-End Cluster Verification

Execute the test suites from any configured client node:

```bash
# 1. Test DNS resolution
./tests/dns-test.sh

# 2. Test HTTPS connection (Strict TLS, no -k)
./tests/https-test.sh

# 3. Test round-robin load balancing (20 requests)
./tests/load-balancing-test.sh

# 4. Test HTTP caching and 304 conditional revalidation
./tests/caching-test.sh
```
