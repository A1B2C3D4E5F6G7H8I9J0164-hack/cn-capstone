# Netforcers — System Architecture

This page is updated for **Phase 2 (22 November 2026)**. DHCP addresses can change and must be checked on assessment day.

The authoritative Phase 2 topology and request-flow diagrams are in [phase2/docs/architecture.md](../phase2/docs/architecture.md). Full implementation results are in [phase2/docs/phase2-final-report.md](../phase2/docs/phase2-final-report.md).

## Four-Mac architecture

| Mac | Owner | Verified IP (22 Nov) | Services |
|---|---|---|---|
| Mac 1 | Aditya Rana | `10.7.17.8` | Primary dnsmasq TCP/UDP 53 |
| Mac 2 | Krishna | `10.7.12.238` | Primary nginx HTTPS TCP 8443 |
| Mac 3 | Rachit Gupta | `10.7.21.149` | Backend A TCP 3001; standby nginx HTTPS TCP 8443 |
| Mac 4 | Saumya Mishra | `10.7.21.214` | Backend B TCP 3002; backup dnsmasq TCP/UDP 53 |

Network: `10.7.0.0/19`, gateway `10.7.0.1`, Wi-Fi `en0`; project name `app.cn-capstone.test`.

```text
             Client
                |
       DNS query (UDP 53)
                |
          +-----+-----+
          |           |
      Mac 1 DNS   Mac 4 backup DNS
          |           |
          +-----+-----+
                |
       A = 10.7.12.238 (TTL 30)
                |
      TCP/TLS to port 8443
                |
        Mac 2 primary nginx
                |
           HTTP proxy
          /          \
 Mac 3 Backend A   Mac 4 Backend B
 10.7.21.149:3001  10.7.21.214:3002
```

During manual controlled edge migration, DNS answers point to Mac 3 `10.7.21.149`, where standby nginx handles HTTPS on port 8443. Firewall B has a documented Mac 3 allowance for this standby route. DNS was restored afterward to Mac 2.

Phase 1-era address tables are superseded by this page and the Phase 2 inventory. For captured evidence see [evidence/](../evidence/) and [Phase 2 evidence](../phase2/evidence/observed-results.md).
