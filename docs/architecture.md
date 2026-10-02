# System Architecture Specification

## Computer Networks Capstone: Private Network Service Platform

### Core Philosophy
"The application stays simple; the network is the project."

---

## 1. Architectural Overview

The Private Network Service Platform is a distributed, multi-tier system engineered across four physical macOS nodes connected via a private local area network (LAN). It replicates modern enterprise cloud application delivery pipelines entirely within an on-premises, isolated environment without dependencies on external public infrastructure.

The architecture decouples client service discovery, edge security termination, load distribution, and application workload execution across specialized network nodes.

---

## 2. Component Inventory and Mapping

| Physical Node | Team Lead | Infrastructure Component | Primary Software | Network Socket | Cloud Architectural Analogy |
|:---|:---|:---|:---|:---|:---|
| **Mac 1** | Aditya Rana | Authoritative DNS Resolver | `dnsmasq` | `10.7.x.x:53` (UDP/TCP) | Amazon Route 53 / CoreDNS |
| **Mac 2** | Krishna | Edge Reverse Proxy & Load Balancer | `nginx` 1.31.6 + OpenSSL | `10.7.5.53:8443` (TCP/TLS) | AWS Application Load Balancer / CloudFront |
| **Mac 3** | Rachit Gupta | Application Server Instance A | Python 3 HTTP Server | `10.7.22.10:3001` (TCP) | AWS EC2 / ECS Container A |
| **Mac 4** | Saumya Mishra | Application Server Instance B | Python 3 HTTP Server | `10.7.7.25:3002` (TCP) | AWS EC2 / ECS Container B |

---

## 3. Request Processing Pipeline

The traversal of an application request from issuance to completion spans seven distinct phases:

```
[ Client ]
    |
    | 1. DNS Query (UDP 53) -> "app.cn-capstone.test"
    v
[ Mac 1: dnsmasq ]
    |
    | 2. DNS Answer (A Record) -> 10.7.5.53
    v
[ Client ]
    |
    | 3. TCP 3-Way Handshake (SYN -> SYN-ACK -> ACK on TCP 8443)
    | 4. TLS 1.2/1.3 Cryptographic Handshake (ClientHello -> ServerHello -> Cert -> Finished)
    | 5. Encrypted HTTP/1.1 Request (GET /api/status)
    v
[ Mac 2: Nginx Edge ]
    |
    | TLS Termination & Inspection
    | Selection of Upstream Node via Round-Robin Algorithm (cn_backends)
    | Injection of Proxy Headers:
    |   - Host: app.cn-capstone.test
    |   - X-Real-IP: <client_ip>
    |   - X-Forwarded-For: <client_ip>
    |   - X-Forwarded-Proto: https
    |
    +---------------------------------+
    |                                 |
    | 6a. HTTP Request (Turn 1)       | 6b. HTTP Request (Turn 2)
    v                                 v
[ Mac 3: Backend A ]              [ Mac 4: Backend B ]
  (10.7.22.10:3001)                 (10.7.7.25:3002)
    |                                 |
    | 7a. Response + Headers:         | 7b. Response + Headers:
    |     - X-Backend: A              |     - X-Backend: B
    |     - ETag: "A-v1"              |     - ETag: "B-v1"
    |     - Cache-Control: max-age=60 |     - Cache-Control: max-age=60
    +---------------------------------+
    |
    v
[ Mac 2: Nginx Edge ]
    |
    | Encapsulate Response inside Active TLS Session
    v
[ Client ]
    (Receives HTTP/1.1 200 OK or 304 Not Modified over TLS)
```

---

## 4. Protocol Layer Contracts

### 4.1 Domain Name Resolution (DNS)
- **Zone Authority**: Authoritative for `*.test` namespace.
- **Record Mapping**:
  - `app.cn-capstone.test` -> `10.7.5.53` (Mac 2 Edge)
  - `api.cn-capstone.test` -> `10.7.5.53` (Mac 2 Edge)
- **TTL Configuration**: Set to 30 seconds to support Phase 2 dynamic failover and traffic redirection.

### 4.2 Edge Security and TLS Termination
- **Protocol Support**: TLS 1.2 and TLS 1.3.
- **Port**: 8443 (configured to avoid requiring root binding on macOS).
- **Certificate Specification**:
  - Key Algorithm: RSA 2048-bit.
  - Signature Algorithm: SHA-256.
  - Common Name (CN): `app.cn-capstone.test`.
  - Subject Alternative Name (SAN): `DNS:app.cn-capstone.test`.
  - Root Trust: Installed in macOS `System.keychain` on all participating client machines.

### 4.3 Load Balancing Strategy
- **Algorithm**: Round-Robin distribution across upstream pool `cn_backends`.
- **Upstream Pool Members**:
  - `10.7.22.10:3001` (Backend A)
  - `10.7.7.25:3002` (Backend B)
- **Session Stickiness**: Disabled to demonstrate deterministic alternation.

### 4.4 HTTP REST Endpoints
- `GET /`:
  - Status: `200 OK`
  - Body: `{"backend": "<A|B>", "status": "ok", "service": "cn-project"}`
- `GET /api/status`:
  - Status: `200 OK`
  - Body: `{"backend": "<A|B>", "status": "ok"}`
- **Conditional Cache Validation**:
  - Request with header: `If-None-Match: "<ETag>"`
  - Server status: `304 Not Modified`
  - Header: `Cache-Control: max-age=60`

---

## 5. Security Architecture and Service Isolation

1. **Client Confidentiality**: Client requests are encrypted in transit over the local Wi-Fi medium using TLS.
2. **Topology Hiding**: Upstream IP addresses (`10.7.22.10`, `10.7.7.25`) and application ports (`3001`, `3002`) are never exposed to clients.
3. **Firewall Isolation (Phase 2)**: Backend instances utilize macOS `pf` packet filtering rules to reject all inbound TCP traffic on ports 3001 and 3002 unless originating from Mac 2 (`10.7.5.53`).
