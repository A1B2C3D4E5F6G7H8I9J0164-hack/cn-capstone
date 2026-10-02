# Network Troubleshooting and Fault Isolation Guide

## Computer Networks Capstone Project

### Core Principle
"The application stays simple; the network is the project."

This guide provides a rigorous, layer-by-layer methodology for isolating and resolving faults across the private network platform.

---

## 1. Systematic Diagnostic Protocol

Always isolate issues starting from the bottom of the protocol stack and progressing upward:

```
[Layer 1/2] Link & Interface -> [Layer 3] IP Routing -> [Layer 7] DNS -> [Layer 4] TCP Sockets -> [Layer 6] TLS -> [Layer 7] Application
```

### Diagnostic Decision Matrix

| Layer | Diagnostic Question | Command to Run | Expected Healthy Result | If It Fails, Next Action |
|:---|:---|:---|:---|:---|
| **L1/L2** | Is Wi-Fi associated and active? | `ifconfig en0 \| grep -E "status\|inet "` | `status: active` and valid `10.7.x.x` IP | Reconnect Wi-Fi; verify DHCP/static IP. |
| **L3** | Can we reach target node over IP? | `ping -c 2 10.7.5.53` | `0.0% packet loss` | Check subnet mask; check ARP table (`arp -a`). |
| **L7 (DNS)** | Does the domain resolve? | `dig app.cn-capstone.test +short` | `10.7.5.53` | Verify `dnsmasq` running on Mac 1; verify client DNS setting. |
| **L4** | Is the destination port open? | `nc -zvw3 10.7.5.53 8443` | `Connection to 10.7.5.53 port 8443 [tcp] succeeded!` | Verify process listening (`lsof -i :8443` or `nginx -t`). |
| **L6 (TLS)** | Is the certificate valid and trusted? | `openssl s_client -connect 10.7.5.53:8443 -servername app.cn-capstone.test` | `Verify return code: 0 (ok)` | Verify SAN extension; import `server.crt` into macOS keychain. |
| **L7 (App)** | Does the HTTP upstream respond? | `curl -v -i https://app.cn-capstone.test:8443/api/status` | `HTTP/1.1 200 OK` | Check backend processes on Mac 3 (`:3001`) and Mac 4 (`:3002`). |

---

## 2. Common Failure Scenarios and Resolutions

### Scenario A: DNS Resolution Timeout
- **Symptom**: `dig: connection timed out; no servers could be reached`
- **Root Cause**: Client machine querying wrong DNS server IP, or `dnsmasq` process is stopped on Mac 1.
- **Resolution**:
  1. On Mac 1, verify dnsmasq status: `sudo brew services list | grep dnsmasq`.
  2. If stopped, start it: `sudo brew services start dnsmasq`.
  3. Verify port 53 is listening: `sudo lsof -i :53`.
  4. On client machine, check configured DNS: `networksetup -getdnsservers Wi-Fi`.

### Scenario B: HTTP 502 Bad Gateway
- **Symptom**: `curl` returns `HTTP/1.1 502 Bad Gateway` from `nginx/1.31.6`.
- **Root Cause**: Nginx edge proxy cannot establish a TCP connection to upstream backends (`10.7.22.10:3001` or `10.7.7.25:3002`).
- **Resolution**:
  1. Test connectivity from Mac 2 to backends:
     ```bash
     curl -i http://10.7.22.10:3001/api/status
     curl -i http://10.7.7.25:3002/api/status
     ```
  2. If connection is refused, the Python backend server is down. Restart the server on Mac 3 or Mac 4:
     ```bash
     python3 server.py
     ```
  3. Check Nginx error logs on Mac 2:
     ```bash
     tail -n 20 /opt/homebrew/var/log/nginx/error.log
     ```

### Scenario C: TLS Certificate Validation Failure
- **Symptom**: `curl: (60) SSL certificate problem: unable to get local issuer certificate`
- **Root Cause**: Client machine has not imported or trusted `server.crt` in its macOS System Keychain.
- **Resolution**:
  1. Copy `server.crt` from Mac 2 to client.
  2. Run keychain trust command:
     ```bash
     sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain server.crt
     ```
  3. Verify trust by running curl without `-k`:
     ```bash
     curl -i https://app.cn-capstone.test:8443/api/status
     ```

### Scenario D: Load Balancer Traffic Unbalanced
- **Symptom**: All requests routed only to Backend A or only to Backend B.
- **Root Cause**: One backend is unreachable, or Nginx session caching / keepalive is pinning connections.
- **Resolution**:
  1. Confirm both backends are active and listening on `0.0.0.0` (not `127.0.0.1`).
  2. In `nginx.conf`, verify the upstream definition contains both servers:
     ```nginx
     upstream cn_backends {
         server 10.7.22.10:3001;
         server 10.7.7.25:3002;
     }
     ```
  3. Test with the automated loop script: `./tests/load-balancing-test.sh`.
