# Netforcers — Updated Phase 2 Architecture (22 Nov 2026)

> IPs below are observed DHCP leases, **not permanent allocations**. Recheck before demo.

| Mac | Member | Address | Phase 2 services |
|---|---|---|---|
| 1 | Aditya | 10.7.17.8 | Primary dnsmasq on port 53 |
| 2 | Krishna | 10.7.12.238 | Primary nginx HTTPS on port 8443 |
| 3 | Rachit | 10.7.21.149 | Backend A port 3001; standby nginx HTTPS port 8443 |
| 4 | Saumya | 10.7.21.214 | Backend B port 3002; backup dnsmasq on port 53 |

LAN: `10.7.0.0/19` (`255.255.224.0`), gateway `10.7.0.1`, Wi-Fi `en0`.

## Normal request/data path

```text
 Client Mac
    | DNS A query: app.cn-capstone.test, UDP/TCP 53
    +-----> Mac 1 DNS 10.7.17.8 (primary)
    +-----> Mac 4 DNS 10.7.21.214 (backup)
    |      reply 10.7.12.238, TTL 30 seconds
    |
    | TCP connection + TLS handshake: 8443
    v
 Mac 2 primary nginx 10.7.12.238:8443
    | HTTPS terminated, HTTP proxied to upstream
    +------> Mac 3 Backend A 10.7.21.149:3001
    +------> Mac 4 Backend B 10.7.21.214:3002
                  |
          HTTP /api/status; X-Backend A/B
```

The nginx upstream uses passive failure detection. Both backends are directly accessible from Mac 2 via PF pass rules, while other ordinary clients are blocked.

## Edge migration path

```text
 Both DNS servers' project A records -> 10.7.21.149 (temporary)
 Client -> TLS port 8443 on Mac 3 standby nginx
 Mac 3 standby nginx -> local Backend A:3001 OR Mac 4 Backend B:3002
                      (Mac 4 PF explicitly allows Mac 3 source IP)
 DNS later restored -> 10.7.12.238 (Mac 2 primary nginx)
```

**Important isolation exception:** Backend B PF allows `10.7.21.149` during standby edge use, beyond the normally permitted primary edge. Explain this intentional exception in the viva.

## Layers and ports

1. DNS: UDP/TCP 53; `app.cn-capstone.test`, `api.cn-capstone.test`; TTL 30.
2. TCP: client to edge 8443; edge to Backend A 3001 / Backend B 3002.
3. TLS: nginx endpoint certificate for private project domain; clients must trust it; test without `curl -k`.
4. HTTP: `/api/status` response, `X-Backend`, `Cache-Control: max-age=60`, ETag and conditional 304 behavior as implemented by backends.

## Risk and persistence

DHCP leases can change; fix DNS records, nginx upstreams, PF IP allowlists, and client DNS addresses if they do. A backup DNS is not a backup application gateway; the standby nginx must be running, TLS-ready, network-reachable, and selected via DNS to take over. The current migration is manual, not automatic HA orchestration.

## Source files

- `phase2/configs/primary-dns.conf`
- `phase2/configs/backup-dns.conf`
- `phase2/configs/primary-nginx.conf`
- `phase2/configs/standby-nginx.conf`
- `phase2/configs/backend-a-firewall.conf`
- `phase2/configs/backend-b-firewall.conf`
- `backend-a/server.py`, `backend-b/server.py`
