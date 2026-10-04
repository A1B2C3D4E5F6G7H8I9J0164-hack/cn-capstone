Yep — here is the **entire `README.md` in one single copy-paste block**. Just copy everything inside the block and paste it into GitHub's `README.md`.

```markdown
# CN Private Network Platform — Mac 1 DNS Server

## 📌 Overview

Mac 1 acts as the **Private DNS Server and Test Client** for the CN Private Network Platform.

It provides:

- Private DNS resolution
- DNS record management
- DNS forwarding for public domains
- Local DNS testing
- DNS traffic monitoring
- DNS failure and backup demonstration
- DNS service for other machines on the private network

The DNS server is implemented using **dnsmasq** on macOS.

---

## 🖥️ Mac 1 — Network Details

| Property | Value |
|---|---|
| Hostname | `cn-dns` |
| Role | Private DNS Server |
| Interface | `en0` |
| Private IP | `10.7.9.245` |
| Gateway | `10.7.0.1` |
| MAC Address | `ee:17:82:aa:3f:9d` |
| DNS Port | `53` |
| Team Domain | `cn-capstone.test` |
| DNS Software | `dnsmasq` |

---

## 🏗️ Network Architecture

```text
                     Private Wi-Fi / LAN
                            │
             ┌──────────────┴──────────────┐
             │                             │
          Mac 1                          Mac 2
         cn-dns                         cn-edge
      10.7.9.245                      10.7.5.53
             │                             │
          dnsmasq                         nginx
           :53                            :8443
             │                             │
             │                    ┌────────┴────────┐
             │                    │                 │
             │                Backend A         Backend B
             │                Mac 3             Mac 4
             │              10.7.22.10        10.7.7.25
             │                :3001              :3002
             │
             ├── app.cn-capstone.test
             │        ↓
             │     10.7.5.53
             │
             └── api.cn-capstone.test
                      ↓
                   10.7.5.53
```

---

## 🔄 Request Flow

```text
Client
   │
   │ DNS Query
   ▼
Mac 1 — dnsmasq
10.7.9.245:53
   │
   │ app.cn-capstone.test
   ▼
10.7.5.53
   │
   ▼
Mac 2 — nginx
10.7.5.53:8443
   │
   ├───────────────┐
   ▼               ▼
Backend A       Backend B
Mac 3           Mac 4
:3001           :3002
```

---

## 🌐 DNS Records

Mac 1 provides the following private DNS records:

```text
app.cn-capstone.test → 10.7.5.53
api.cn-capstone.test → 10.7.5.53
```

Mac 2 (`10.7.5.53`) is the edge server.

---

## ⚙️ DNS Configuration

### Main Configuration

The main dnsmasq configuration is located at:

```text
/opt/homebrew/etc/dnsmasq.conf
```

Current configuration:

```conf
port=53

listen-address=127.0.0.1,10.7.9.245

bind-interfaces

no-resolv

server=8.8.8.8

domain-needed

bogus-priv

cache-size=1000

local-ttl=30

conf-dir=/opt/homebrew/etc/dnsmasq.d,*.conf
```

---

## 📁 Project DNS Configuration

Project-specific DNS records are stored in:

```text
/opt/homebrew/etc/dnsmasq.d/project.conf
```

Contents:

```conf
address=/app.cn-capstone.test/10.7.5.53
address=/api.cn-capstone.test/10.7.5.53
```

---

## 📦 Installation

Install dnsmasq using Homebrew:

```bash
brew install dnsmasq
```

Verify installation:

```bash
dnsmasq --version
```

---

## 📂 Create Configuration Directory

```bash
sudo mkdir -p "$(brew --prefix)/etc/dnsmasq.d"
```

---

## 📝 Create dnsmasq Configuration

```bash
BREW_PREFIX="$(brew --prefix)"
MAC1_IP=$(ipconfig getifaddr en0)
GATEWAY=$(route -n get default | awk '/gateway:/{print $2}')

sudo tee "$BREW_PREFIX/etc/dnsmasq.conf" >/dev/null <<EOF
port=53
listen-address=127.0.0.1,$MAC1_IP
bind-interfaces
no-resolv
server=8.8.8.8
domain-needed
bogus-priv
cache-size=1000
local-ttl=30
conf-dir=$BREW_PREFIX/etc/dnsmasq.d,*.conf
EOF
```

---

## 🧪 Configuration Validation

Validate the dnsmasq configuration:

```bash
sudo "$(brew --prefix)/opt/dnsmasq/sbin/dnsmasq" \
  --test \
  --conf-file="$(brew --prefix)/etc/dnsmasq.conf"
```

Expected:

```text
dnsmasq: syntax check OK.
```

---

## 🚀 DNS Service

Check whether dnsmasq is listening on port 53:

```bash
sudo lsof -nP -iTCP:53 -iUDP:53
```

Expected listeners:

```text
127.0.0.1:53
10.7.9.245:53
```

Check the service:

```bash
brew services list | grep dnsmasq
```

---

## 🔎 DNS Testing

### Test Public DNS Forwarding

```bash
dig @127.0.0.1 google.com
```

Expected:

```text
status: NOERROR
SERVER: 127.0.0.1#53
```

DNS flow:

```text
Mac 1
  ↓
dnsmasq
  ↓
8.8.8.8
  ↓
Public DNS
```

---

## 🔍 Test Private DNS Records

### Test Application Record

```bash
dig +short @127.0.0.1 app.cn-capstone.test
```

Expected:

```text
10.7.5.53
```

### Test API Record

```bash
dig +short @127.0.0.1 api.cn-capstone.test
```

Expected:

```text
10.7.5.53
```

---

## 🧾 Detailed DNS Query

```bash
dig @127.0.0.1 app.cn-capstone.test
```

Expected:

```text
status: NOERROR

QUESTION SECTION:
app.cn-capstone.test. IN A

ANSWER SECTION:
app.cn-capstone.test. 30 IN A 10.7.5.53

SERVER:
127.0.0.1#53
```

Important values:

```text
Domain: app.cn-capstone.test
Type: A
Answer: 10.7.5.53
TTL: 30 seconds
Status: NOERROR
```

---

## 📡 LAN DNS Testing

Mac 1 listens on:

```text
10.7.9.245:53
```

Test with:

```bash
dig +short @10.7.9.245 app.cn-capstone.test
```

Expected:

```text
10.7.5.53
```

### Current Environment Note

The Mac is managed by MDM and the macOS Application Firewall currently blocks incoming connections to dnsmasq.

Therefore:

```text
Local DNS:
127.0.0.1:53 → Working

LAN DNS:
10.7.9.245:53 → dnsmasq listening

External client access:
Currently blocked by managed firewall
```

The firewall policy must permit incoming dnsmasq connections before other Macs can use Mac 1 as their DNS resolver.

---

## 🛡️ Firewall

Check firewall state:

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

Check dnsmasq firewall status:

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw \
--getappblocked \
"/opt/homebrew/Cellar/dnsmasq/2.93/sbin/dnsmasq"
```

Current state:

```text
Incoming connection to dnsmasq is blocked.
```

The Mac is managed by MDM:

```text
Enrolled via DEP: Yes
MDM enrollment: Yes
```

Therefore, the firewall rule cannot be changed from Terminal on this machine.

---

## 📊 DNS Traffic Capture

DNS traffic can be captured using tcpdump:

```bash
sudo tcpdump -i en0 -nn -w "$HOME/Desktop/cn-dns.pcap" port 53
```

Generate a DNS request while the capture is running:

```bash
dig @127.0.0.1 app.cn-capstone.test
```

Stop tcpdump with:

```text
Ctrl + C
```

The resulting capture:

```text
~/Desktop/cn-dns.pcap
```

can be opened in Wireshark.

---

## 🦈 Wireshark Verification

Open:

```text
cn-dns.pcap
```

Use the Wireshark display filter:

```text
dns
```

Look for the query:

```text
app.cn-capstone.test
```

The response should contain:

```text
10.7.5.53
```

DNS exchange:

```text
DNS Query
    ↓
app.cn-capstone.test
    ↓
Mac 1 dnsmasq
    ↓
DNS Response
    ↓
10.7.5.53
```

---

## 🔥 DNS Failure Demonstration

Stop dnsmasq:

```bash
sudo brew services stop dnsmasq
```

A client configured with a primary and backup DNS resolver can then test whether the project domain resolves through the backup resolver.

Restore the DNS service:

```bash
sudo brew services start dnsmasq
```

---

## ⏱️ TTL Demonstration

The DNS configuration uses:

```conf
local-ttl=30
```

Therefore, project DNS records use a short TTL.

Flush the macOS DNS cache:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

Then test:

```bash
dig app.cn-capstone.test
```

The TTL can be observed using:

```bash
dig @127.0.0.1 app.cn-capstone.test
```

Expected:

```text
app.cn-capstone.test. 30 IN A 10.7.5.53
```

---

## 🧰 Useful Troubleshooting Commands

### Check Active Interface

```bash
IFACE=$(route -n get default | awk '/interface:/{print $2}')
echo "$IFACE"
```

### Get Mac 1 IP

```bash
ipconfig getifaddr en0
```

### Get Gateway

```bash
route -n get default | awk '/gateway:/{print $2}'
```

### Get MAC Address

```bash
ifconfig en0 | awk '/ether / {print $2; exit}'
```

### Check Port 53

```bash
sudo lsof -nP -iTCP:53 -iUDP:53
```

### Check dnsmasq Process

```bash
ps aux | grep '[d]nsmasq'
```

### Validate Configuration

```bash
sudo "$(brew --prefix)/opt/dnsmasq/sbin/dnsmasq" \
  --test \
  --conf-file="$(brew --prefix)/etc/dnsmasq.conf"
```

---

# 📋 Mac 1 Final Status

| Component | Status |
|---|---|
| Mac 1 IP | `10.7.9.245` |
| dnsmasq | ✅ Running |
| Port 53 | ✅ Listening |
| Local DNS | ✅ Working |
| Public DNS forwarding | ✅ Working |
| `app.cn-capstone.test` | ✅ `10.7.5.53` |
| `api.cn-capstone.test` | ✅ `10.7.5.53` |
| DNS TTL | ✅ 30 seconds |
| Wireshark evidence | ✅ Available |
| LAN DNS | ⚠️ Blocked by managed firewall |
| Other Mac DNS clients | ⏳ Pending firewall permission |

---

# 🎯 Project Architecture

```text
                    CN PRIVATE NETWORK
                           │
                           │
                    ┌──────▼──────┐
                    │    Mac 1    │
                    │   cn-dns    │
                    │ 10.7.9.245  │
                    │              │
                    │  dnsmasq     │
                    │    :53       │
                    └──────┬───────┘
                           │
                    DNS Resolution
                           │
              app.cn-capstone.test
                           │
                           ▼
                    ┌──────────────┐
                    │    Mac 2     │
                    │   cn-edge    │
                    │ 10.7.5.53    │
                    │              │
                    │ nginx :8443  │
                    └──────┬───────┘
                           │
                 ┌─────────┴─────────┐
                 │                   │
                 ▼                   ▼
            Backend A           Backend B
             Mac 3                Mac 4
          10.7.22.10            10.7.7.25
             :3001                 :3002
```

---

# 👥 Team Components

| Machine | Role | IP | Service |
|---|---|---|---|
| Mac 1 | DNS Server | `10.7.9.245` | dnsmasq `:53` |
| Mac 2 | Edge Server | `10.7.5.53` | nginx `:8443` |
| Mac 3 | Backend A | `10.7.22.10` | `:3001` |
| Mac 4 | Backend B | `10.7.7.25` | `:3002` |

---

# ✅ Mac 1 Responsibilities

- [x] Run dnsmasq
- [x] Maintain private DNS records
- [x] Resolve `app.cn-capstone.test`
- [x] Resolve `api.cn-capstone.test`
- [x] Forward public DNS queries
- [x] Configure DNS TTL
- [x] Capture DNS traffic
- [x] Analyze DNS traffic using Wireshark
- [x] Demonstrate DNS failure
- [ ] Provide LAN DNS to other Macs — pending managed firewall permission

---

# 🚀 Project Summary

**CN Private Network Platform**

**Component:** Mac 1 — Private DNS Server + Test Client

**Hostname:** `cn-dns`

**Private IP:** `10.7.9.245`

**DNS Server:** `dnsmasq`

**DNS Port:** `53`

**Domain:** `cn-capstone.test`

**Platform:** macOS + Homebrew

**Edge Server:** `10.7.5.53:8443`

**Backend A:** `10.7.22.10:3001`

**Backend B:** `10.7.7.25:3002`
```
