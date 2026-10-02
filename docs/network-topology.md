# Network Topology and Addressing Specification

## Computer Networks Capstone Project

### Core Principle
"The application stays simple; the network is the project."

---

## 1. Physical and Logical Network Environment

The platform operates across four physical macOS nodes connected to a dedicated, unrouted IEEE 802.11 Wi-Fi / Ethernet local area network segment. All communication occurs locally without passing through an external gateway or internet router.

### Subnet Parameters
- Network Address: `10.7.0.0`
- Subnet Mask: `255.255.0.0` (`/16`)
- Broadcast Address: `10.7.255.255`
- IP Allocation Method: Static configuration / verified DHCP lease

---

## 2. Machine Inventory and IP Assignment

| Machine | Hostname | Hardware Role | Team Member | IPv4 Address | Subnet Mask | Active Interface | Listening Sockets |
|:---|:---|:---|:---|:---|:---|:---|:---|
| **Mac 1** | `cn-dns` | Private DNS Server | Aditya Rana | `10.7.x.x` | `255.255.0.0` | `en0` | `53/UDP`, `53/TCP` |
| **Mac 2** | `cn-edge` | Edge Proxy / LB | Krishna | `10.7.5.53` | `255.255.0.0` | `en0` | `8443/TCP`, `80/8080/TCP` |
| **Mac 3** | `cn-backend-a` | App Instance A | Rachit Gupta | `10.7.22.10` | `255.255.0.0` | `en0` | `3001/TCP` |
| **Mac 4** | `cn-backend-b` | App Instance B | Saumya Mishra | `10.7.7.25` | `255.255.0.0` | `en0` | `3002/TCP` |

---

## 3. Network Topology Diagram

```
========================================================================================
                          PHYSICAL BROADCAST DOMAIN: 10.7.0.0/16
========================================================================================

                 +---------------------------------------------+
                 |                    MAC 1                    |
                 |                 Aditya Rana                 |
                 |             Private DNS Server              |
                 |                 (10.7.x.x)                  |
                 +---------------------------------------------+
                                        |
                 +----------------------+----------------------+
                 |                                             |
   [DNS Queries: UDP 53]                         [DNS Answers: A 10.7.5.53]
                 |                                             |
                 v                                             v
  +-----------------------------+               +-----------------------------+
  |            MAC 1            |               |            MAC 4            |
  |         (Client A)          |               |         Saumya Mishra       |
  |                             |               |      (Test Client Mode)     |
  +-----------------------------+               +-----------------------------+
                 |                                             |
                 +----------------------+----------------------+
                                        |
                        [HTTPS Requests: TCP 8443]
                        [TLS 1.2/1.3 Encrypted Payload]
                                        v
                 +---------------------------------------------+
                 |                    MAC 2                    |
                 |                   Krishna                   |
                 |        Edge Reverse Proxy & Load Balancer   |
                 |                 (10.7.5.53)                 |
                 |                 Port: 8443                  |
                 +---------------------------------------------+
                                        |
                 +----------------------+----------------------+
                 |                                             |
    [Upstream HTTP/1.1: 3001]                     [Upstream HTTP/1.1: 3002]
                 |                                             |
                 v                                             v
  +-----------------------------+               +-----------------------------+
  |            MAC 3            |               |            MAC 4            |
  |         Rachit Gupta        |               |         Saumya Mishra       |
  |       Backend Server A      |               |       Backend Server B      |
  |         (10.7.22.10)        |               |         (10.7.7.25)         |
  |          Port: 3001         |               |          Port: 3002         |
  +-----------------------------+               +-----------------------------+
```

---

## 4. Socket Inventory and Binding Table

| Node | Service | Process Name | Bound Socket | Protocol | Scope | Purpose |
|:---|:---|:---|:---|:---|:---|:---|
| **Mac 1** | DNS Daemon | `dnsmasq` | `10.7.x.x:53`, `127.0.0.1:53` | UDP/TCP | LAN Accessible | Resolves `.test` domains for all cluster nodes |
| **Mac 2** | Reverse Proxy | `nginx: master` | `0.0.0.0:8443` | TCP | LAN Accessible | Terminates TLS and load-balances inbound traffic |
| **Mac 3** | App Server A | `python3` | `0.0.0.0:3001` | TCP | LAN Accessible | Serves Application REST requests (`X-Backend: A`) |
| **Mac 4** | App Server B | `python3` | `0.0.0.0:3002` | TCP | LAN Accessible | Serves Application REST requests (`X-Backend: B`) |

---

## 5. Address Resolution Protocol (ARP) Flow

Before IP packets can traverse the LAN, physical MAC addresses are resolved using ARP:

1. **Client to Edge ARP Query**:
   ```
   Who has 10.7.5.53? Tell 10.7.x.x (Broadcast: ff:ff:ff:ff:ff:ff)
   ```
2. **Edge ARP Reply**:
   ```
   10.7.5.53 is at <mac2_hardware_address> (Unicast)
   ```
3. **ARP Table Verification**:
   ```bash
   arp -a | grep 10.7.
   ```
