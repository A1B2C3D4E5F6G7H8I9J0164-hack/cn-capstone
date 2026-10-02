# Private Network Service Platform
## Computer Networks Capstone Course Project

### Core Principle
"The application stays simple; the network is the project."

---

## 1. Project Purpose and Overview

This project implements a fully functional, highly available private network service platform deployed across four physical macOS workstations connected to an isolated local area network (LAN). Without relying on external cloud providers, pre-configured managed services, or public domain registrars, the platform demonstrates the complete lifecycle of a client network request.

A client machine on the private network:
1. Issues requests using a private domain name (`app.cn-capstone.test`).
2. Resolves the domain via an internal authoritative DNS server running `dnsmasq`.
3. Establishes a secure Transport Layer Security (TLS 1.2 / 1.3) connection to a reverse proxy and load balancer running `nginx`.
4. Dispatches the request through a round-robin load balancer to one of two isolated backend application server instances.
5. Observes, captures, and validates every protocol transition across the stack using tools including `curl`, `dig`, `openssl`, and `Wireshark`.

---

## 2. Team Organization and Machine Roles

The platform distributes network responsibilities across four distinct physical macOS laptops. Each workstation assumes a defined network role mapping directly to modern enterprise and cloud architectural equivalents.

| Machine | Team Member | Primary Network Role | Services Running | Network Endpoints & Ports | Cloud Infrastructure Equivalent |
|:---|:---|:---|:---|:---|:---|
| **Mac 1** | **Aditya Rana** | Private DNS Resolver + Test Client | `dnsmasq`, `dig`, `nslookup`, `curl` | Port 53 (UDP/TCP) | Managed DNS (AWS Route 53, CoreDNS) |
| **Mac 2** | **Krishna** | Edge Reverse Proxy + Load Balancer + TLS Termination | `nginx` (1.31.6), OpenSSL TLS Engine | Port 8443 (HTTPS), Port 80/8080 (HTTP) | Cloud Load Balancer (AWS ALB, GCP NLB), CDN Edge |
| **Mac 3** | **Rachit Gupta** | Backend Application Server 1 | Python HTTP REST Service | Port 3001 (HTTP) | Application Server Instance A |
| **Mac 4** | **Saumya Mishra** | Backend Application Server 2 + Test Client | Python HTTP REST Service, `curl`, browser | Port 3002 (HTTP) | Application Server Instance B + Internal Consumer |

---

## 3. Network Inventory and Addressing Scheme

The cluster operates on a private Class A local area subnet (`10.7.0.0/16`). All addresses are statically verified to prevent DHCP contention during live evaluation.

| Machine Role | Hostname | Assigned IPv4 Address | Subnet Mask | Active Interface | MAC Address Format |
|:---|:---|:---|:---|:---|:---|
| **Mac 1: DNS Server** | `cn-dns` | `10.7.x.x` | `255.255.0.0` (/16) | `en0` (Wi-Fi) | `xx:xx:xx:xx:xx:xx` |
| **Mac 2: Edge / Proxy** | `cn-edge` | `10.7.5.53` | `255.255.0.0` (/16) | `en0` (Wi-Fi) | `xx:xx:xx:xx:xx:xx` |
| **Mac 3: Backend A** | `cn-backend-a` | `10.7.22.10` | `255.255.0.0` (/16) | `en0` (Wi-Fi) | `xx:xx:xx:xx:xx:xx` |
| **Mac 4: Backend B** | `cn-backend-b` | `10.7.7.25` | `255.255.0.0` (/16) | `en0` (Wi-Fi) | `xx:xx:xx:xx:xx:xx` |

### Reserved Namespace
- Primary Domain: `app.cn-capstone.test`
- API Alias: `api.cn-capstone.test`
- Reserved Top-Level Domain (TLD): `.test` (RFC 2606 and RFC 6761 compliant, preventing conflicts with macOS Multicast DNS / Bonjour `.local` domains).

---

## 4. End-to-End Network Topology and Request Flow

### 4.1 Topology Diagram

```
+---------------------------------------------------------------------------------------+
|                                    PRIVATE LAN                                        |
|                                    10.7.0.0/16                                        |
+---------------------------------------------------------------------------------------+
            |                                                      |
            |                                                      |
    [1] DNS Query (UDP 53)                                  [2] DNS Response
    "app.cn-capstone.test?"                                  "10.7.5.53"
            |                                                      |
            v                                                      |
+--------------------------+                                       |
|          MAC 1           | --------------------------------------+
|       Aditya Rana        |
|    Private DNS Server    |
|       (dnsmasq:53)       |
+--------------------------+
            ^
            |
    +---------------+
    |  CLIENT NODE  |
    | (Mac 1/Mac 4) |
    +---------------+
            |
            | [3] TCP 3-Way Handshake (SYN -> SYN-ACK -> ACK on TCP 8443)
            | [4] TLS 1.2/1.3 Handshake (ClientHello -> ServerHello -> Cert -> Finished)
            | [5] Encrypted HTTPS Request: GET /api/status (SNI: app.cn-capstone.test)
            v
+---------------------------------------------------------------------------------------+
|                                        MAC 2                                          |
|                                       Krishna                                         |
|                      Edge Reverse Proxy & Round-Robin Load Balancer                   |
|                                    (nginx:8443)                                       |
|                                                                                       |
|   TLS Termination Point                                                               |
|   Upstream Group: cn_backends                                                         |
|     - 10.7.22.10:3001 (Backend A)                                                     |
|     - 10.7.7.25:3002  (Backend B)                                                     |
+---------------------------------------------------------------------------------------+
                |                                                   |
                | [6a] HTTP/1.1 Request                             | [6b] HTTP/1.1 Request
                |      Round-Robin Turn 1                           |      Round-Robin Turn 2
                v                                                   v
+-------------------------------+                   +-------------------------------+
|             MAC 3             |                   |             MAC 4             |
|          Rachit Gupta         |                   |         Saumya Mishra         |
|       Backend Server A        |                   |       Backend Server B        |
|       (HTTP Port 3001)        |                   |       (HTTP Port 3002)        |
|                               |                   |                               |
| Responds:                     |                   | Responds:                     |
| - Header: X-Backend: A        |                   | - Header: X-Backend: B        |
| - Header: ETag: "A-v1"        |                   | - Header: ETag: "B-v1"        |
| - Cache-Control: max-age=60   |                   | - Cache-Control: max-age=60   |
| - Body: {"backend":"A",...}   |                   | - Body: {"backend":"B",...}   |
+-------------------------------+                   +-------------------------------+
                |                                                   |
                +-------------------------+-------------------------+
                                          |
                                [7] Backend Response
                                          |
                                          v
                              (TLS Encrypted Return)
                                          |
                                          v
                                    [CLIENT NODE]
                                  HTTP/1.1 200 OK
                                    X-Backend: A / B
```

### 4.2 Detailed Request Lifecycle
1. **Name Lookup (Application Layer / UDP)**: The client application executes a DNS query for `app.cn-capstone.test` via UDP port 53 targeting Mac 1 (`dnsmasq`).
2. **Authoritative Answer**: Mac 1 returns the A record `10.7.5.53` (Mac 2 Edge).
3. **Transport Layer Connection (TCP)**: The client initiates an active TCP open to socket `10.7.5.53:8443` through a standard three-way handshake (`SYN`, `SYN-ACK`, `ACK`).
4. **Cryptographic Negotiation (TLS)**: Over the established TCP socket, client and edge negotiate TLS ciphers, exchange keys, and validate the Subject Alternative Name (SAN) certificate issued to `app.cn-capstone.test`.
5. **Encrypted Application Data (HTTPS)**: The client transmits `GET /api/status HTTP/1.1` encrypted inside TLS records.
6. **TLS Termination and Upstream Proxy**: Mac 2 decrypts the request at the edge, checks the upstream load-balancing pool (`cn_backends`), appends proxy headers (`X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`), and initiates an internal HTTP/1.1 connection to either Mac 3 (`10.7.22.10:3001`) or Mac 4 (`10.7.7.25:3002`).
7. **Backend Processing**: The target backend processes the REST call and returns JSON payload along with backend identifier headers (`X-Backend: A` or `X-Backend: B`) and HTTP caching directives.
8. **Client Delivery**: Mac 2 encapsulates the upstream response inside the TLS session and delivers it to the client. The client receives the response with complete protocol integrity.

---

## 5. OSI vs TCP/IP Protocol Stack Mapping

The following table documents how every protocol implemented in this project maps across both the ISO/OSI 7-Layer Reference Model and the Internet (TCP/IP) Protocol Suite:

| OSI Layer | TCP/IP Layer | Protocol / Technology | Implementation in this Project | Observation & Verification Method |
|:---|:---|:---|:---|:---|
| **Layer 7: Application** | Application | DNS (Domain Name System) | `dnsmasq` authoritative service resolving `app.cn-capstone.test` to `10.7.5.53` | `dig app.cn-capstone.test`, `nslookup`, Wireshark filter `dns` |
| **Layer 7: Application** | Application | HTTP/1.1 (Hypertext Transfer) | REST endpoints `/` and `/api/status`, custom headers `X-Backend`, `Cache-Control`, `ETag` | `curl -i`, browser dev tools, Wireshark filter `http` |
| **Layer 6: Presentation** | Application / Transport | TLS 1.2 / TLS 1.3 | Cryptographic handshakes, RSA/ECDSA key exchange, AES-GCM data encryption terminated at Mac 2 | `openssl s_client`, Wireshark filter `tls` |
| **Layer 5: Session** | Application / Transport | TLS Session Management | Session establishment, cipher negotiation, connection keep-alive | OpenSSL session output, Wireshark `ChangeCipherSpec` / `Encrypted Handshake Message` |
| **Layer 4: Transport** | Transport | TCP (Transmission Control) | End-to-end reliable byte stream, 3-way handshake (`SYN`-`SYN/ACK`-`ACK`), sequence/ACK numbering, flow control | Wireshark filter `tcp.port == 8443`, `tcp.flags.syn == 1` |
| **Layer 4: Transport** | Transport | UDP (User Datagram) | Low-overhead connectionless queries for DNS resolution on port 53 | Wireshark filter `udp.port == 53` |
| **Layer 3: Network** | Internet | IPv4 & ICMP | Private addressing (`10.7.0.0/16`), routing between nodes, ICMP echo request/reply | `ping 10.7.5.53`, `netstat -nr`, `ifconfig en0` |
| **Layer 2: Data Link** | Network Access / Link | IEEE 802.11 Wi-Fi / Ethernet | MAC frame addressing, ARP resolution between IP addresses and physical hardware | `arp -a`, Wireshark frame layer analysis |
| **Layer 1: Physical** | Network Access / Link | Physical Transceiver | Wireless RF (2.4GHz/5GHz 802.11) / physical network medium | Interface carrier status (`ifconfig en0 status: active`) |

---

## 6. Phase 1: Build and Observe (Mandatory Tasks)

### Task A: Establish the Private LAN
- **Objective**: Interconnect all four macOS workstations on an isolated private Wi-Fi/LAN segment and confirm full IP reachability.
- **Verification Commands**:
  ```bash
  # Check active IP address and network mask
  ifconfig en0 | grep "inet "

  # Verify bidirectional connectivity to all peers
  ping -c 3 10.7.5.53     # Mac 2 (Edge)
  ping -c 3 10.7.22.10    # Mac 3 (Backend A)
  ping -c 3 10.7.7.25     # Mac 4 (Backend B)
  ```
- **Success Criteria**: 0% packet loss across all pairwise host ping checks.

---

### Task B: Configure a Private DNS Server
- **Objective**: Mac 1 runs `dnsmasq` to serve private authoritative DNS records for the `.test` namespace.
- **Configuration** (`/opt/homebrew/etc/dnsmasq.d/project.conf` on Mac 1):
  ```conf
  address=/app.cn-capstone.test/10.7.5.53
  address=/api.cn-capstone.test/10.7.5.53
  listen-address=127.0.0.1,10.7.x.x
  bind-interfaces
  ```
- **Client Configuration**:
  On Mac 2, Mac 3, and Mac 4, set the primary DNS resolver to Mac 1 IP:
  ```bash
  # Set DNS resolver on macOS via networksetup
  sudo networksetup -setdnsservers Wi-Fi 10.7.x.x
  ```
- **Verification Commands**:
  ```bash
  # Standard resolution via configured system resolver
  dig app.cn-capstone.test +noall +answer

  # Explicit query against Mac 1 DNS server
  dig @10.7.x.x app.cn-capstone.test +short
  ```
- **Expected Output**:
  ```
  app.cn-capstone.test.    0    IN    A    10.7.5.53
  ```

---

### Task C: Build Two Simple Backend Services
- **Objective**: Mac 3 and Mac 4 run independent lightweight HTTP REST services.
- **Service Specifications**:
  - **Backend A (Mac 3)**: Binds to `0.0.0.0:3001`.
  - **Backend B (Mac 4)**: Binds to `0.0.0.0:3002`.
  - Endpoints:
    - `GET /`: Returns JSON health status and service label.
    - `GET /api/status`: Returns JSON status object.
  - Required Response Headers:
    - `X-Backend: A` (from Mac 3)
    - `X-Backend: B` (from Mac 4)
    - `Cache-Control: max-age=60`
    - `ETag: "A-v1"` or `"B-v1"`
- **Direct Backend Verification (from Mac 2)**:
  ```bash
  curl -i http://10.7.22.10:3001/api/status
  curl -i http://10.7.7.25:3002/api/status
  ```

---

### Task D: Configure Edge Reverse Proxy and Load Balancer
- **Objective**: Mac 2 acts as the single unified entry point using `nginx`, terminating public connections and distributing traffic evenly between backends.
- **Configuration** (`nginx.conf`):
  ```nginx
  upstream cn_backends {
      server 10.7.22.10:3001;
      server 10.7.7.25:3002;
  }

  server {
      listen 8443 ssl;
      server_name app.cn-capstone.test;

      ssl_certificate     /opt/homebrew/etc/nginx/certs/server.crt;
      ssl_certificate_key /opt/homebrew/etc/nginx/certs/server.key;

      location / {
          proxy_pass http://cn_backends;
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header Connection "";
      }
  }
  ```
- **Verification Script** (`tests/load-balancing-test.sh`):
  ```bash
  ./tests/load-balancing-test.sh
  ```
- **Verified Live Output**:
  ```
  === LOAD BALANCING TEST ===
  URL: https://app.cn-capstone.test:8443/api/status

  Request 01: X-Backend: A
  Request 02: X-Backend: B
  Request 03: X-Backend: A
  Request 04: X-Backend: B
  ...
  Request 19: X-Backend: A
  Request 20: X-Backend: B

  Backend A responses: 10
  Backend B responses: 10

  === LOAD BALANCING TEST PASSED ===
  ```
- **Evidence Reference**: See `evidence/task-d/Mac2-TaskD-LoadBalancing.png`.

---

### Task E: Add HTTPS / TLS Termination
- **Objective**: Implement valid cryptographic TLS termination on Mac 2 with a Subject Alternative Name (SAN) certificate trusted by all clients.
- **OpenSSL Configuration** (`tls/openssl.cnf.example`):
  ```ini
  [req]
  default_bits = 2048
  prompt = no
  default_md = sha256
  distinguished_name = dn
  x509_extensions = v3_req

  [dn]
  C = IN
  ST = Haryana
  L = Sonipat
  O = CN Project
  OU = Computer Networks
  CN = app.cn-capstone.test

  [v3_req]
  subjectAltName = @alt_names
  basicConstraints = critical,CA:FALSE
  keyUsage = critical,digitalSignature,keyEncipherment
  extendedKeyUsage = serverAuth

  [alt_names]
  DNS.1 = app.cn-capstone.test
  ```
- **Certificate Trust Installation (Client Macs)**:
  ```bash
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain server.crt
  ```
- **Strict Verification (No `-k` or `--insecure` allowed)**:
  ```bash
  curl -i https://app.cn-capstone.test:8443/api/status
  ```
- **Verified Response**:
  ```http
  HTTP/1.1 200 OK
  Server: nginx/1.31.6
  Date: Thu, 01 Oct 2026 11:26:17 GMT
  Content-Type: application/json
  Content-Length: 32
  Connection: keep-alive
  Cache-Control: max-age=60
  ETag: "A-v1"
  X-Backend: A

  {"backend": "A", "status": "ok"}
  ```
- **Evidence References**:
  - Certificate SAN Inspection: `evidence/task-e/Mac2-TaskE-Certificate.png`
  - Valid HTTPS Response: `evidence/task-e/Mac2-TaskE-HTTPS.png`

---

### Task F: Demonstrate HTTP Caching Behavior
- **Objective**: Prove understanding of HTTP cache control, validators, and conditional revalidation.
- **Workflow**:
  1. **Initial Request**: The client requests the resource and receives `Cache-Control: max-age=60` and `ETag: "B-v1"`.
  2. **Conditional Validation**: The client issues a subsequent request with `If-None-Match: "B-v1"`.
  3. **Server Response**: The backend validates that the representation is unchanged and returns `HTTP/1.1 304 Not Modified` with zero response body, conserving bandwidth.
- **Execution**:
  ```bash
  # Step 1: Initial Fresh Request
  curl -i https://app.cn-capstone.test:8443/

  # Step 2: Conditional Request with ETag validator
  curl -i -H 'If-None-Match: "B-v1"' https://app.cn-capstone.test:8443/api/status
  ```
- **Verified Output (304 Not Modified)**:
  ```http
  HTTP/1.1 304 Not Modified
  Server: nginx/1.31.6
  Date: Thu, 01 Oct 2026 11:49:29 GMT
  Connection: keep-alive
  ETag: "B-v1"
  Cache-Control: max-age=60
  X-Backend: B
  ```
- **Evidence References**:
  - Cache 200 OK Initial Fetch: `evidence/task-f/Mac2-TaskF-Cache-200.png`
  - Cache 304 Not Modified Validation: `evidence/task-f/Mac2-TaskF-Public-304.png`

---

### Task G: Capture Complete Protocol Flow
- **Objective**: Use Wireshark to record and dissect a single unified client request from DNS query to application delivery.
- **Protocol Flow Breakdown**:
  1. **DNS Resolution**:
     - Client port: Ephemeral (e.g., `51842/UDP`)
     - Server port: `53/UDP`
     - Query: `Standard query 0x1a2b A app.cn-capstone.test`
     - Response: `Standard query response 0x1a2b A 10.7.5.53`
  2. **TCP Three-Way Handshake**:
     - Packet 1: `Client -> Edge [SYN] Seq=0 Win=65535 Len=0 MSS=1460`
     - Packet 2: `Edge -> Client [SYN, ACK] Seq=0 Ack=1 Win=65535 Len=0 MSS=1460`
     - Packet 3: `Client -> Edge [ACK] Seq=1 Ack=1 Win=65535 Len=0`
  3. **TLS Cryptographic Handshake**:
     - `Client Hello`: Advertises supported TLS versions (TLS 1.3, TLS 1.2), cipher suites, and Server Name Indication (`app.cn-capstone.test`).
     - `Server Hello`: Edge selects cipher suite (e.g., `TLS_AES_256_GCM_SHA384`).
     - `Certificate`: Server transmits public X.509 certificate chain.
     - `Server Key Exchange` & `Server Hello Done`.
     - `Client Key Exchange`, `ChangeCipherSpec`, `Finished`.
  4. **Application Data**:
     - All subsequent HTTP payloads appear as `Application Data Protocol: Hypertext Transfer Protocol with TLS encryption` in Wireshark, demonstrating payload confidentiality.

---

## 7. Verified Evidence and Demonstration Proofs

All core Phase 1 tasks have been executed, verified, and captured in the repository evidence archive:

| Task | Test Performed | Captured Evidence File | Verified Output Summary |
|:---|:---|:---|:---|
| **Task D** | Round-robin load balancing distribution | `evidence/task-d/Mac2-TaskD-LoadBalancing.png` | 20 sequential requests perfectly balanced: 10 responses from Backend A, 10 responses from Backend B. |
| **Task E** | OpenSSL X.509 SAN certificate inspection | `evidence/task-e/Mac2-TaskE-Certificate.png` | `CN=app.cn-capstone.test`, `X509v3 Subject Alternative Name: DNS:app.cn-capstone.test`, valid until Oct 2027. |
| **Task E** | Strict HTTPS connection without `-k` | `evidence/task-e/Mac2-TaskE-HTTPS.png` | HTTP/1.1 200 OK, `Server: nginx/1.31.6`, payload `{"backend": "A", "status": "ok"}`. |
| **Task F** | HTTP caching: initial resource fetch | `evidence/task-f/Mac2-TaskF-Cache-200.png` | HTTP/1.1 200 OK with `Cache-Control: max-age=60`, `ETag: "B-v1"`, `X-Backend: B`. |
| **Task F** | HTTP caching: conditional revalidation | `evidence/task-f/Mac2-TaskF-Public-304.png` | HTTP/1.1 304 Not Modified returned upon sending `If-None-Match: "B-v1"`. Empty response body. |

---

## 8. Phase 1 Required Failure Scenarios and Observations

The platform underwent deliberate fault injection to prove system comprehension and layer isolation:

| Failure Scenario | Fault Injected | Observed Symptom | Underlying Network Explanation |
|:---|:---|:---|:---|
| **1. Wrong DNS Resolver** | Client DNS set to non-existent IP (`10.7.200.200`) | `dig` returns `connection timed out; no servers could be reached`. Direct `ping 10.7.5.53` still succeeds. | Proves that the Name Resolution Layer and the IP Routing Layer operate independently. Direct IP communication remains intact even if domain resolution fails. |
| **2. DNS Poisoning / Wrong IP** | DNS record on Mac 1 configured to point `app.cn-capstone.test` to `10.7.99.99` | DNS resolves instantly to `10.7.99.99`, but `curl` fails with `Operation timed out` or `Connection refused`. | Proves that DNS is merely a directory service, not a transport connection. Successful DNS resolution does not guarantee transport-level reachability. |
| **3. Single Backend Terminated** | Backend A (`10.7.22.10:3001`) terminated via `SIGINT` | Client continues to receive HTTP/1.1 200 OK responses with `X-Backend: B` for 100% of requests. Zero client-visible errors. | Demonstrates upstream proxy fault tolerance: Nginx detects connection refusal on port 3001 and reroutes traffic automatically to healthy upstream members. |
| **4. Both Backends Terminated** | Both Backend A and Backend B terminated | DNS resolves normally to Mac 2; TCP and TLS handshakes succeed; Nginx immediately returns `HTTP/1.1 502 Bad Gateway`. | Clearly isolates the Edge boundary from the Application boundary. The edge proxy and TLS layers function properly, but cannot establish an upstream socket to the application layer. |
| **5. Wrong Port on Client** | Client attempts connection to `https://app.cn-capstone.test:9443` | Client receives immediate `Connection refused` (TCP RST packet received). | Demonstrates that the destination host is reachable at the Network layer (Layer 3), but no process is bound to the target socket at the Transport layer (Layer 4). |

---

## 9. Phase 2: Harden, Recover, and Troubleshoot

### Extension A: Backup DNS Resolver and High Availability
- **Architecture**: A secondary `dnsmasq` instance is deployed on Mac 4 with identical zone records.
- **Client Configuration**: Clients are configured with two resolver addresses:
  ```bash
  sudo networksetup -setdnsservers Wi-Fi 10.7.x.x 10.7.7.25
  ```
- **Demonstration**: When Mac 1 primary DNS is taken offline (`brew services stop dnsmasq`), clients automatically fall back to Mac 4 without interruption.

### Extension B: DNS TTL and Controlled Traffic Cutover
- **Configuration**: DNS records configured with a 30-second TTL (`address=/app.cn-capstone.test/10.7.5.53,30`).
- **Demonstration**:
  1. Record updated to point to a new standby edge IP.
  2. Immediate client queries continue to receive the cached answer from local cache.
  3. Upon TTL expiration (or manual cache flush via `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`), clients immediately transition to the updated address.

### Extension C: Service Isolation via macOS `pf` Packet Filter
- **Objective**: Prevent clients from bypassing the reverse proxy and accessing backend ports 3001 and 3002 directly.
- **Rule Definition** (`/etc/pf.anchors/cn_isolation` on Mac 3 and Mac 4):
  ```
  # Allow traffic to backend ports ONLY from Mac 2 (Edge IP 10.7.5.53)
  pass in quick on en0 proto tcp from 10.7.5.53 to any port {3001, 3002}
  block in quick on en0 proto tcp from any to any port {3001, 3002}
  ```
- **Demonstration**: Direct connection attempt from client Mac fails with `Operation timed out` or `Connection refused`, while requests routed through `https://app.cn-capstone.test:8443` succeed.

### Extension D: High-Availability Failover and Single Point of Failure (SPOF) Analysis
- **Nginx Failover Tuning**:
  ```nginx
  upstream cn_backends {
      server 10.7.22.10:3001 max_fails=2 fail_timeout=5s;
      server 10.7.7.25:3002 max_fails=2 fail_timeout=5s;
  }
  ```
- **SPOF Analysis**: While the backend application layer is fully redundant, Mac 2 (Edge Nginx) remains a Single Point of Failure. In an enterprise production network, this is mitigated by:
  1. Deploying dual active-passive edge proxies paired with Virtual Router Redundancy Protocol (VRRP / Keepalived) sharing a Virtual IP (VIP).
  2. BGP Anycast routing directing traffic to the nearest surviving edge router.
  3. DNS round-robin across multiple public edge IP addresses.

### Extension E: Controlled Edge Migration
- Standby Nginx configuration staged on Mac 4.
- Authoritative DNS modified on Mac 1 to point `app.cn-capstone.test` to Mac 4.
- Client observed transitioning seamlessly once the DNS record propagates.

### Extension F: Systematic Layer-by-Layer Troubleshooting Framework
When diagnosing any unknown network failure, the team follows a strict deterministic bottom-up protocol audit:

```
[Layer 1/2]  Check Physical/Link Status   -> ifconfig en0 (status: active, valid IP assigned)
     |
     v
[Layer 3]    Check IP Reachability         -> ping -c 2 <target_ip> (ICMP Echo)
     |
     v
[Layer 7]    Check Name Resolution         -> dig @<dns_ip> app.cn-capstone.test +short
     |
     v
[Layer 4]    Check Transport Port / Socket -> nc -zvw3 <target_ip> 8443
     |
     v
[Layer 5/6]  Check TLS Certificate & Cipher -> openssl s_client -connect <target_ip>:8443 -servername app.cn-capstone.test
     |
     v
[Layer 7]    Check Application Response    -> curl -v -i https://app.cn-capstone.test:8443/api/status
```

---

## 10. Final Demonstration Runbook (11-Step Evaluation Sequence)

This execution guide mirrors Section 8 of the Computer Networks Capstone evaluation protocol:

| Step | Action | Execution Command | Evaluator Verification Checklist |
|:---:|:---|:---|:---|
| **1** | Present Topology & IP Inventory | Open project documentation and display network table | Confirm 4 host roles: Mac 1 (DNS), Mac 2 (Edge), Mac 3 (Backend A), Mac 4 (Backend B). |
| **2** | Confirm LAN Reachability | `ping -c 2 10.7.5.53 && ping -c 2 10.7.22.10 && ping -c 2 10.7.7.25` | 0% packet loss, valid ICMP RTT. |
| **3** | Resolve Domain from Client | `dig app.cn-capstone.test +short` | Query resolves to Mac 2 IP (`10.7.5.53`) via team DNS. |
| **4** | HTTPS Request via Domain | `curl -i https://app.cn-capstone.test:8443/api/status` | HTTP 200 OK returned; trusted certificate with no `-k` bypass. |
| **5** | Demonstrate Load Balancing | `./tests/load-balancing-test.sh` | Alternating `X-Backend: A` and `X-Backend: B` headers observed over 20 requests. |
| **6** | Wireshark Protocol Flow Evidence | Open `.pcap` capture in Wireshark | Display DNS query/response, TCP 3-way handshake (`SYN`-`SYN/ACK`-`ACK`), TLS ClientHello and Certificate. |
| **7** | Demonstrate HTTP Caching | `curl -i -H 'If-None-Match: "A-v1"' https://app.cn-capstone.test:8443/api/status` | Confirm `HTTP/1.1 304 Not Modified` and `Cache-Control: max-age=60`. |
| **8** | Fail One Backend | Stop Backend A on Mac 3 (`Ctrl+C`); rerun client curl | Requests continue to succeed seamlessly via Backend B with `X-Backend: B`. |
| **9** | Demonstrate Phase 2 Resilience | Stop Mac 1 DNS; show resolution fallback to Mac 4 secondary | Name resolution continues uninterrupted. |
| **10** | Diagnose Faculty-Injected Fault | Execute 5-step troubleshooting methodology | Systematic diagnosis identifying faulty layer (DNS, TCP, TLS, or Upstream). |
| **11** | Individual Viva Voce | Individual verbal examination | Each student defends their configured component and protocol theory. |

---

## 11. Individual Viva Voce Preparation Guide

### For Aditya Rana (Mac 1 - DNS Specialist)
- **What is the difference between an authoritative and recursive DNS server?**
  *dnsmasq in our project acts as an authoritative server for our private zone `*.test` by returning configured IP mappings directly from local config, while forwarding unknown public queries recursively to upstream resolvers.*
- **Why did we use `.test` instead of `.local`?**
  *RFC 6762 reserves `.local` for Multicast DNS (mDNS/Bonjour). On macOS, queries ending in `.local` are intercepted by mDNSResponder over multicast IP `224.0.0.251`, breaking unicast DNS resolution.*
- **What happens when a DNS query is sent over UDP vs TCP?**
  *Standard queries use UDP port 53 for low latency. If the DNS response exceeds 512 bytes (or EDNS0 buffer limits) or during zone transfers (AXFR), DNS falls back to TCP port 53.*

### For Krishna (Mac 2 - Edge, Proxy, and Security Specialist)
- **What is the difference between a Reverse Proxy and a Forward Proxy?**
  *A forward proxy acts on behalf of clients to access external servers, hiding client identities. A reverse proxy acts on behalf of backend servers, receiving requests from clients, terminating security sessions, and routing internally, hiding backend topology.*
- **How does TLS termination work?**
  *The TLS handshake concludes at the Nginx edge on Mac 2 using the server's private key. The payload is decrypted by Nginx and proxied as plain HTTP over the internal network to backends, offloading cryptographic overhead from application nodes.*
- **Why is SNI (Server Name Indication) required?**
  *SNI is an extension to the TLS protocol where the client specifies the target hostname in the `ClientHello` message before the certificate is returned. This enables a single edge proxy on one IP address to serve multiple virtual hosts with distinct TLS certificates.*

### For Rachit Gupta (Mac 3 - Backend A Specialist)
- **What is an ETag and how does conditional caching save resources?**
  *An ETag (Entity Tag) is an HTTP validator representing a specific version of a resource. When a client includes `If-None-Match: <etag>`, the server checks if the resource has changed; if not, it returns `304 Not Modified` with empty body, eliminating redundant data transfer.*
- **Why must backend applications bind to `0.0.0.0` instead of `127.0.0.1`?**
  *`127.0.0.1` is the loopback interface, accessible only from processes running locally on the same physical machine. BINDing to `0.0.0.0` allows the server socket to listen on all network interfaces, including the LAN IP (`10.7.22.10`), enabling connections from Mac 2.*

### For Saumya Mishra (Mac 4 - Backend B and Client Testing Specialist)
- **What constitutes a socket pair?**
  *A socket pair uniquely identifies a four-tuple TCP connection: `(Source IP, Source Port, Destination IP, Destination Port)`. For example: `(10.7.7.25, 52194, 10.7.5.53, 8443)`.*
- **What is the difference between an ephemeral port and a well-known port?**
  *Well-known ports (0-1023) and registered ports (1024-49151) are dedicated to specific listening services (e.g., DNS on 53, HTTPS on 443/8443). Ephemeral ports (49152-65535 on macOS) are dynamically assigned by the client OS kernel for the duration of a client connection.*

---

## 12. Repository File Structure

```
cn-capstone/
├── README.md                      # Comprehensive Project Documentation
├── edge/
│   ├── README.md                  # Mac 2 Edge Configuration Documentation
│   └── nginx.conf.example         # Production Nginx Reverse Proxy & Load Balancer Config
├── tls/
│   ├── README.md                  # TLS Architecture & Certificate Trust Guide
│   └── openssl.cnf.example        # OpenSSL SAN (Subject Alternative Name) Configuration
├── dns/
│   ├── dnsmasq.conf.example       # Authoritative DNS Server Main Configuration
│   └── project.conf.example       # Private Zone Domain Mappings (.test)
├── backend-a/
│   ├── README.md                  # Backend A Deployment Instructions
│   └── server.py                  # HTTP REST Application Server A (Port 3001)
├── backend-b/
│   ├── README.md                  # Backend B Deployment Instructions
│   └── server.py                  # HTTP REST Application Server B (Port 3002)
├── tests/
│   ├── dns-test.sh                # Automated Domain Resolution Test Suite
│   ├── https-test.sh              # Strict TLS Verification Test Suite
│   ├── load-balancing-test.sh     # 20-Iteration Round-Robin Verification Test
│   └── caching-test.sh            # HTTP 304 Validation & Cache-Control Test
├── evidence/
│   ├── task-d/
│   │   └── Mac2-TaskD-LoadBalancing.png  # Live Proof: 20-Request Alternating Load Balancing
│   ├── task-e/
│   │   ├── Mac2-TaskE-Certificate.png    # Live Proof: OpenSSL SAN Certificate Verification
│   │   └── Mac2-TaskE-HTTPS.png          # Live Proof: Valid HTTPS Response without -k
│   └── task-f/
│       ├── Mac2-TaskF-Cache-200.png      # Live Proof: Initial 200 OK with ETag & Cache-Control
│       └── Mac2-TaskF-Public-304.png     # Live Proof: 304 Not Modified Conditional Validation
└── docs/
    ├── architecture.md            # Detailed Architectural Reference
    ├── network-topology.md        # Network Topology and Addressing Specifications
    ├── setup-guide.md             # Node-by-Node Step-by-Step Installation Runbook
    ├── troubleshooting.md         # Fault Diagnosis and Layer Isolation Guide
    └── viva-notes.md              # Comprehensive Team Viva Voce Revision Guide
```
