# Phase 2 Evidence — Results Observed in Team Terminal Sessions

**Provenance:** This is a curated summary of terminal outputs and test descriptions shared in the team's working session on 22 November 2026. It is **not** a raw terminal transcript, packet capture, screenshot, or claim that a test was independently rerun during preparation of this file. Configurations in `../configs/` were separately checked on GitHub.

| Extension | Procedure reported | Observation shared | Evidence status |
|---|---|---|---|
| A Backup DNS | Query Mac 4's dnsmasq directly | Backup returned project edge address `10.7.12.238` after restoration | Direct resolver query observed; ordinary client HTTPS with primary OFF not fully proven |
| B TTL | Configure DNS TTL 30; query Mac 2 caching dnsmasq at localhost port 5354; change authoritative A record to standby IP | Cache retained `10.7.12.238` at remaining TTL **1** while authoritative resolver returned `10.7.21.149` TTL **30**; after expiry cache returned new target TTL 30 | TTL expiration observed; manual cache flush not conclusively logged |
| C PF | Apply `com.apple/cncapstone` anchors on backend hosts, probe directly from edge and non-edge | Edge HTTP to each backend returned 200; client Mac 1 connection to both backend ports timed out; HTTPS through edge 200 | Positive and negative probes observed |
| D Backend HA | Stop Backend A, issue 6 HTTPS edge requests, restart Backend A | Six requests during outage returned HTTP 200 from B; after recovery both A and B appeared again | Failover and recovery observed |
| E Edge migration | Deploy nginx standby on Mac 3, query it using `curl --resolve`, change both DNS records to `10.7.21.149`, send domain-based HTTPS, then restore primary | Standby and domain-based HTTPS returned HTTP 200; Mac 3 nginx access log recorded requests; DNS restored to `10.7.12.238` | Cutover observed; simultaneous old-vs-new cached clients not fully captured |
| F Faculty fault | To be performed by faculty during review | Not performed | Pending |

## Directly quoted terminal details supplied for Mac 4 DNS migration

```text
$ dig @10.7.21.214 app.cn-capstone.test +short
10.7.21.149
```

The DNS config was subsequently edited to replace `10.7.21.149` with `10.7.12.238` and dnsmasq restarted; the final committed backup config has the restored primary IP. The terminal log also showed a successful Homebrew restart and ownership warnings (not an indication that the DNS request failed).

## Evidence still to collect and attach as genuine files

- A: Screenshots / saved text showing primary DNS stopped and a client resolving **without directly specifying** the backup IP, plus successful HTTPS.
- B: Exact before/after output for manual cache flush on the actual caching resolver.
- C: PF rule listings and positive/negative client connection output saved with host and timestamp; rollback restoration evidence if required.
- D: Saved before/down/recovered request output with `X-Backend`.
- E: Saved standby access log and distinct cached/uncached DNS answers during the cutover.
- F: Faculty challenge diagnosis after the actual evaluation.

Existing `evidence/task-*` screenshots document **Phase 1** DNS/TCP/TLS/caching and are not relabeled as new Phase 2 packet captures. Do not represent these curated summaries as independent raw evidence.
