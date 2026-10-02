# Comprehensive Viva Voce Revision Guide

## Computer Networks Capstone Project

### Core Principle
"The application stays simple; the network is the project."

This reference document prepares all four team members for the technical oral examination (viva voce). Every student must understand both their specific subsystem and the complete end-to-end network operation.

---

## 1. System-Wide Concepts (All Team Members)

### Q1: What is the core difference between DNS resolution and an HTTP/HTTPS connection?
**Answer**:
- **DNS Resolution** is an Application-layer lookup protocol typically executed over UDP port 53. Its sole function is resolving a human-readable domain name (e.g., `app.cn-capstone.test`) to a destination IP address (`10.7.5.53`). No application data or HTTP connection is initiated during DNS resolution.
- **HTTP/HTTPS Connection** is the application-data session established *after* DNS completes. It requires a TCP three-way handshake on port 8443, a cryptographic TLS handshake, and the exchange of HTTP request/response payloads.

### Q2: Why did we build our infrastructure on macOS laptops rather than using cloud services?
**Answer**:
Cloud platforms (AWS, GCP, Azure) abstract away foundational networking mechanics behind automated control planes and Virtual Private Clouds (VPCs). Building directly on physical macOS laptops requires configuring raw IP routing, socket bindings, DNS zones, TLS certificates, reverse proxy load balancers, and packet filters manually, giving direct visibility into packets via Wireshark.

### Q3: What is the sequence of events when a user navigates to `https://app.cn-capstone.test:8443/api/status`?
**Answer**:
1. Client checks local DNS cache. If missed, sends UDP query to Mac 1 on port 53.
2. Mac 1 returns `A 10.7.5.53`.
3. Client initiates TCP three-way handshake (`SYN`, `SYN-ACK`, `ACK`) to `10.7.5.53:8443`.
4. Client and Mac 2 execute TLS cryptographic handshake; client verifies the SAN certificate.
5. Client sends encrypted `GET /api/status HTTP/1.1` over TLS.
6. Mac 2 terminates TLS, inspects URI, selects an upstream backend via round-robin, and proxies the request to Mac 3 (`:3001`) or Mac 4 (`:3002`).
7. Backend processes request, returning JSON with header `X-Backend: A` (or `B`).
8. Mac 2 encapsulates backend response inside TLS and transmits it to the client.

---

## 2. Aditya Rana (Mac 1 - DNS Specialist)

### Q1: What is the role of `dnsmasq` in our network?
**Answer**:
`dnsmasq` serves as our private authoritative DNS server. It binds to port 53 and responds to queries for our private zone `*.test`. For all domain requests within this zone, it returns our configured IP (`10.7.5.53`). For non-project queries, it can forward recursively to public resolvers (like `1.1.1.1`).

### Q2: Why did we use `.test` instead of `.local`?
**Answer**:
`.local` is officially reserved by RFC 6762 for Multicast DNS (mDNS) and Apple Bonjour. On macOS, any hostname ending in `.local` is intercepted by `mDNSResponder` and broadcasted over link-local multicast IP `224.0.0.251`. This causes unicast DNS lookups to fail. RFC 2606 explicitly reserves `.test` for private testing.

### Q3: What is DNS TTL, and why is it important in production cutovers?
**Answer**:
Time-To-Live (TTL) is an integer field in DNS resource records indicating how many seconds a resolver or client may cache the record before querying the authoritative server again. In production cutovers, administrators lower the TTL (e.g., from 86400s to 30s) prior to migration so that clients quickly discover the updated server IP once the cutover occurs.

---

## 3. Krishna (Mac 2 - Edge, Proxy, and TLS Specialist)

### Q1: What is TLS Termination and why is it performed at the edge?
**Answer**:
TLS Termination occurs when the edge reverse proxy decrypts inbound TLS traffic from the client, handling cryptographic negotiation, certificate validation, and key exchange. Decrypted traffic is then forwarded internally over the LAN to backend application servers. This centralizes certificate management, offloads CPU-intensive cryptography from application nodes, and allows the proxy to inspect HTTP headers for intelligent routing.

### Q2: What is the difference between Round-Robin and Least-Connections load balancing?
**Answer**:
- **Round-Robin**: Passes requests sequentially down the list of upstream servers regardless of active connections or workload duration. Ideal for homogeneous requests.
- **Least-Connections**: Directs incoming requests to the upstream server with the lowest count of active, uncompleted connections. Ideal for variable-length requests or database-heavy transactions.

### Q3: Why is Server Name Indication (SNI) essential in modern HTTPS?
**Answer**:
In standard TLS, the handshake occurs before the HTTP request (and therefore the HTTP `Host` header) is sent. SNI is an extension to the TLS protocol that includes the requested hostname in the initial unencrypted `ClientHello` message. This allows the server to select and present the correct certificate among multiple virtual hosts hosted on a single IP address.

---

## 4. Rachit Gupta (Mac 3 - Backend A & Caching Specialist)

### Q1: What is the function of HTTP Caching headers (`Cache-Control`, `ETag`, `304 Not Modified`)?
**Answer**:
- `Cache-Control: max-age=60`: Informs the client that the response remains fresh for 60 seconds and can be served directly from local cache without contacting the server.
- `ETag`: An entity tag that serves as a unique fingerprint/hash of the resource state.
- `304 Not Modified`: When the client sends `If-None-Match: <etag>`, the server checks if the resource has changed. If unchanged, it returns status 304 with no body, saving network bandwidth and processing time.

### Q2: What is the difference between binding to `0.0.0.0` vs `127.0.0.1`?
**Answer**:
- `127.0.0.1` is the loopback interface (`lo0`). Sockets bound to `127.0.0.1` only accept connections originated from the same local machine.
- `0.0.0.0` represents INADDR_ANY, instructing the socket to listen on all available network interfaces, including the physical LAN interface (`en0` / `10.7.22.10`).

---

## 5. Saumya Mishra (Mac 4 - Backend B & Transport Layer Specialist)

### Q1: What is a socket pair and a 4-tuple connection?
**Answer**:
A socket pair uniquely identifies a bidirectional TCP connection across the entire network using a 4-tuple:
1. Source IP Address
2. Source Port Number (Ephemeral port, e.g., 52341)
3. Destination IP Address
4. Destination Port Number (Well-known port, e.g., 8443)

### Q2: How does TCP guarantee reliable data transfer?
**Answer**:
TCP provides reliability through:
- **Sequence Numbers**: Every byte of data is indexed, allowing reassembly in proper order.
- **Acknowledgements (ACKs)**: The receiver notifies the sender of successfully received byte streams.
- **Retransmission Timers**: If an ACK is not received within a calculated Round-Trip Time (RTT), the sender retransmits the lost segment.
- **Flow Control (Sliding Window)**: The receiver advertises a Window size (`win=`) to prevent buffer overflow.
- **Checksums**: Ensures payload integrity and detects corrupted segments.
