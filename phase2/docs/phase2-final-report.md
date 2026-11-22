# Netforcers — Computer Networks Capstone Phase 2 Final Report
**Prepared:** 22 November 2026  
**Team:** Krishna (Mac 2, edge), Aditya Rana (Mac 1, primary DNS), Rachit Gupta (Mac 3, Backend A/standby edge), Saumya Mishra (Mac 4, Backend B/backup DNS)  
**Repository:** https://github.com/CosmicMagnetar/cn-capstone  
**Evidence policy:** Results below are derived from the team's terminal outputs and test descriptions shared during implementation. The distinction between *observed*, *configuration verified*, and *requires live confirmation* is deliberate. Do not treat this report as a substitute for raw screenshots, timestamped terminal logs, or packet captures.

## 1. Objective and changes from Phase 1

Phase 1 provided a private LAN, project DNS, HTTPS nginx reverse proxy, two Python backends, load balancing, HTTP caching headers/conditional 304 behavior, and Wireshark observations. Phase 2 extends it with a secondary DNS resolver, a short DNS TTL and controlled record change, PF firewall isolation of backend ports, backend failure/recovery handling, and a standby HTTPS nginx with DNS cutover.

The team used the university's existing DHCP network rather than reassigning static addresses. Old Phase 1 IPs were replaced after verifying current addresses; DHCP changes remain a pre-demonstration risk.

## 2. Current network/service inventory (22 Nov 2026)

| Device | Owner | DHCP IP | Running service / role |
|---|---|---|---|
| Mac 1 | Aditya Rana | `10.7.17.8` | Primary dnsmasq, TCP/UDP 53 |
| Mac 2 | Krishna | `10.7.12.238` | Primary nginx HTTPS, TCP 8443 |
| Mac 3 | Rachit Gupta | `10.7.21.149` | Backend A, TCP 3001; standby nginx HTTPS, TCP 8443 |
| Mac 4 | Saumya Mishra | `10.7.21.214` | Backend B, TCP 3002; backup dnsmasq, TCP/UDP 53 |

Wi-Fi interface `en0`; subnet `10.7.0.0/19`; mask `255.255.224.0`; gateway `10.7.0.1`. Private names: `app.cn-capstone.test` and `api.cn-capstone.test`. Normal DNS A record target: `10.7.12.238`; temporary standby edge target: `10.7.21.149`.

The tested HTTPS endpoint is `https://app.cn-capstone.test:8443/api/status`; explicit port 8443 is required by the current configuration. TLS certificate/key must exist locally for nginx; the private key is **not** in GitHub.

## 3. Extension A — Backup DNS resolver

**Implementation:** dnsmasq on Mac 1 and Mac 4 exposes the same project A records and `local-ttl=30`. Client DNS settings were configured with both resolver addresses, primary `10.7.17.8` and secondary `10.7.21.214`.

**Observed:** The backup resolver answered direct `dig @10.7.21.214 app.cn-capstone.test` lookups with `10.7.12.238` after DNS was restored. The primary service was stopped and later restarted during testing. The shared records do **not** contain conclusive timestamped proof of an ordinary, unmodified client HTTPS request succeeding *while* Mac 1 was down. Record that end-to-end test during the final demonstration.

**Learning:** Redundant DNS servers reduce dependency on a single resolver, but a secondary resolver helps only when clients are configured to use it and the network can reach it. DNS outages must be distinguished from a backend or edge application outage.

## 4. Extension B — TTL, cached resolution, record change and flush

**Implementation:** Both authoritative dnsmasq files set `local-ttl=30`. A temporary caching dnsmasq on Mac 2 listened at `127.0.0.1:5354` and forwarded requests to Mac 1 for a controlled cache demonstration.

**Observed:** After the primary record was changed from `10.7.12.238` to `10.7.21.149`, the caching resolver still returned the previous address with **TTL 1** while direct authoritative DNS returned the new address with **TTL 30**. After expiry the caching resolver returned `10.7.21.149` with TTL 30. The authoritative record was subsequently restored to `10.7.12.238`, and the temporary caching resolver was stopped.

**Not yet conclusively captured:** A before/after log proving *manual cache flush* causes immediate resolution of the new address. Capture this separately instead of claiming it passed.

**Learning:** A small TTL narrows, but does not eliminate, a cutover window because clients may use cached answers until expiration. Manually clearing the relevant resolver's cache allows newly published records to be seen sooner.

## 5. Extension C — Backend isolation with PF

**Implementation:** macOS PF anchors `com.apple/cncapstone` restrict direct access to `10.7.21.149:3001` and `10.7.21.214:3002`. Mac 2 is allowed into both backends; Mac 3 is also allowed into Backend B to support the standby edge migration demonstration.

**Observed:** Mac 2 direct HTTP probes to both backend IPs returned 200, while Mac 1 TCP connection probes to ports 3001 and 3002 timed out. Mac 1 continued to obtain HTTPS 200 via the nginx edge. PF rule listings showed the intended passes and blocks, and PF was enabled.

**Security qualification:** The Mac 4 exception allowing source `10.7.21.149` is an intentional Phase 2 standby-edge exception; therefore the literal requirement 'only Mac 2 can access backends' is relaxed for the edge migration exercise. Demonstrate or explain this exception clearly.

**Rollback:** Remove only this project's PF anchor rules, and release the PF enable token saved on each machine. Do not globally disable other firewall rules. Preserve the original configuration before changing it.

**Learning:** Network service isolation enforces the intended path through the HTTPS gateway; an application remaining functional via nginx while direct client TCP connections fail demonstrates the boundary. Exceptions should be minimized and documented.

## 6. Extension D — Passive backend failure/recovery

**Implementation:** The primary nginx upstream lists Backend A `10.7.21.149:3001` and Backend B `10.7.21.214:3002`. nginx handles backend failures passively.

**Observed:** With both backends up, repeated HTTPS requests returned HTTP 200 and both `X-Backend: A` and `X-Backend: B`. After Backend A was stopped on Rachit's Mac, six requests through Mac 2 succeeded with Backend B. When Backend A restarted, some early requests were still directed to Backend B; subsequent requests included A and B again.

**Learning:** Passive failover improves application availability despite a backend failure. The primary edge itself remains an ordinary-operation single point of failure until DNS and clients cut over to the standby edge.

## 7. Extension E — Standby nginx and DNS cutover

**Implementation:** Mac 3 runs nginx on TCP 8443 using the same private domain/certificate and both backend addresses. Both project DNS services can be updated to make `app.cn-capstone.test` resolve to `10.7.21.149`.

**Observed:** From Mac 2, a `curl --resolve` HTTPS test directly targeting `10.7.21.149:8443` returned HTTP 200. After both DNS servers were switched to Mac 3, ordinary HTTPS requests using the domain returned 200; the standby nginx access log recorded requests. Both DNS services were then restored to `10.7.12.238`, and the primary edge again served HTTPS successfully. During a separate backup DNS migration probe, Mac 4 returned `10.7.21.149` and was then restored.

**Evidence limitation:** These tests prove the standby can serve traffic and records can be switched. They do not fully establish a captured, simultaneous old-client/new-client cutover timing trace for Extension E. The TTL caching test in Extension B supports the expected explanation; an E-specific side-by-side log remains desirable.

**Learning:** DNS cutover can reroute new connections to a prepared standby edge without adding physical hardware. The edge switch still depends on resolver behavior, valid TLS configuration and backend connectivity, so it is a controlled migration rather than instantaneous automatic failover.

## 8. Extension F — Faculty-injected fault (evaluation only)

**Status:** Awaiting the faculty's live injected fault; it cannot be marked as passed ahead of evaluation.

**Diagnosis order:**
1. DNS: `dig @10.7.17.8 app.cn-capstone.test`, then `dig @10.7.21.214 app.cn-capstone.test`; inspect scoped resolver/client settings.
2. TCP: `nc -G 3 -vz 10.7.12.238 8443`; on edge, test backend ports and PF rules.
3. TLS: `curl -v https://app.cn-capstone.test:8443/api/status` without `-k`; inspect certificate trust and hostname.
4. HTTP/application: `curl -i https://app.cn-capstone.test:8443/api/status`; inspect `X-Backend`, nginx logs, and Python backend processes.

**Learning:** Diagnosing in layer order prevents unnecessary application edits when the actual failure is DNS, connectivity or certificate trust.

## 9. Troubleshooting findings from setup

- Phase 1's old DHCP IPs in nginx upstream and client resolver settings caused incorrect routing; replaced them with current tested addresses.
- A stale scoped resolver on Mac 4 still pointed at an obsolete Mac 1 address and required correction.
- Certificate trust had to be established so `curl` worked without `-k`.
- Backend recovery was not immediate in every nginx request; an initial run after restart still selected B.
- macOS PF can isolate backend service ports without blocking normal HTTPS access through the edge.
- Changing authoritative DNS is not the same as instantly clearing every client's cache.
- Starting Homebrew dnsmasq with sudo produced ownership warnings; this needs operational awareness but does not by itself indicate failed DNS service.

## 10. Evidence inventory and limitations

**Committed source/config:** `backend-a/server.py`, `backend-b/server.py`, `phase2/configs/{primary-dns,backup-dns,primary-nginx,standby-nginx,backend-a-firewall,backend-b-firewall}.conf`.  
**Phase 1 evidence already in GitHub:** `evidence/task-a` through `evidence/task-g`, including Wireshark PNGs for DNS, TCP and TLS. Those captures are from Phase 1, not fresh Phase 2 traces.  
**Phase 2 test descriptions:** `phase2/evidence/observed-results.md` and `phase2/evidence/source-notes.md`. These are traceable text summaries of shared test outputs, **not original screenshots or .pcap files**.

**Outstanding before claiming full completion:** capture a standard client HTTPS request with primary DNS stopped, manual DNS cache flush, E-specific before/after TTL migration timing, a safe firewall rollback proof if required, and live faculty challenge results. Recheck DHCP IPs immediately before assessment.

## 11. Conclusion

The team implemented and tested the major resilience mechanisms across four Macs. All six Phase 2 configuration files and both backend implementations are present on `main`. The tested system demonstrates redundant DNS lookup, measurable TTL behavior, backend isolation, passive backend failover/recovery and manual standby-edge migration. The project is **not** represented as having completed the future faculty challenge or missing evidence capture steps.
