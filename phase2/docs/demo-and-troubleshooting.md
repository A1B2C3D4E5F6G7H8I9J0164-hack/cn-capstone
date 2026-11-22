# Phase 2 Live Evaluation — Checklist and Troubleshooting

## Preflight (run on the actual Macs)

All: `ipconfig getifaddr en0`; `ping -c 2 10.7.12.238`. Verify the actual DHCP addresses before trusting the report table.

Mac 1 DNS: `dig @10.7.17.8 app.cn-capstone.test +noall +answer`.  
Mac 4 DNS: `dig @10.7.21.214 app.cn-capstone.test +noall +answer`.  
Edge local upstream: `curl -i --max-time 4 http://10.7.21.149:3001/api/status` and `curl -i --max-time 4 http://10.7.21.214:3002/api/status`.  
TLS domain: `curl -i https://app.cn-capstone.test:8443/api/status` (do not use `-k`).  
Primary nginx: `nginx -t`.  
Backend PF: `sudo pfctl -a com.apple/cncapstone -sr`.

## Official 11-step sequence

1. Show `phase2/docs/architecture.md`, IP table, and service inventory.
2. Verify each IP and connectivity on the current LAN.
3. `dig` private project domain on a client; show both primary and backup resolver answers.
4. Open the service with the private name and HTTPS, without `curl -k`; note project uses port 8443.
5. Repeated `curl -i` requests, identifying `X-Backend: A` and `X-Backend: B`.
6. Show saved real Wireshark DNS, TCP and TLS captures under `evidence/task-g/`; explain protocols, layers and ports.
7. Show HTTP `Cache-Control` / ETag and conditional `304 Not Modified` response.
8. Stop Backend A under supervision; verify continued HTTPS 200 from B; restart A; show both backends resume.
9. Show backup DNS, TTL/caching and controlled edge migration. Record the cache flush demonstration.
10. Handle the faculty's injected fault live, starting with DNS and moving up through TCP, TLS and HTTP.
11. Each teammate explains components and one observed failure/learning point.

## Fault isolation

**DNS** — `dig @10.7.17.8 app.cn-capstone.test +short`, `dig @10.7.21.214 app.cn-capstone.test +short`; `scutil --dns`; inspect any `/etc/resolver/cn-capstone.test` override for stale IPs.

**TCP** — `nc -G 3 -vz 10.7.12.238 8443`; from Mac 2 check ports 3001 and 3002. On backend hosts inspect PF anchor.

**TLS** — `curl -v https://app.cn-capstone.test:8443/api/status`; validate hostname, certificate location, trust and nginx config. Do not bypass verification with `-k`.

**HTTP** — `curl -i https://app.cn-capstone.test:8443/api/status`; check `X-Backend`, `Cache-Control`, nginx error/access logs and Python processes.

## Safe rollback guidance

- For DNS test, restore `address=/app.cn-capstone.test/10.7.12.238` and `address=/api.cn-capstone.test/10.7.12.238` on **both** DNS servers, then restart/recheck dnsmasq. Keep a copy of each pre-change file.
- For PF test, restore pre-test rules or flush **only** the project's anchor (`sudo pfctl -a com.apple/cncapstone -F rules`) if authorized. Do not run blanket firewall disable commands.
- For backend failure test, restart Backend A and verify both X-Backend values before the next test.
- For edge cutover, confirm both authoritative DNS servers point to Mac 2 after restoration and test domain-based HTTPS again.

## Outstanding honesty checks

Do not mark Extension F passed before the faculty injects a fault. Do not claim manual cache flushing or simultaneous cached-client edge migration timing was captured unless an actual log or screenshot demonstrates it.
