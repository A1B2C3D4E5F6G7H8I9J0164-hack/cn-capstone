# Source and verification notes for Phase 2 evidence

Prepared 22 Nov 2026. This document identifies exactly what supports the companion `observed-results.md`.

## Source types

1. **Current GitHub project files** (reviewed 22 Nov): `phase2/configs/primary-dns.conf`, `backup-dns.conf`, `primary-nginx.conf`, `standby-nginx.conf`, `backend-a-firewall.conf`, `backend-b-firewall.conf`, `backend-a/server.py`, `backend-b/server.py`. GitHub file links: https://github.com/CosmicMagnetar/cn-capstone/tree/main/phase2/configs
2. **Team-provided console outputs during setup/testing** (22 Nov): HTTPS 200 with X-Backend A/B, backend failure/recovery outputs, PF positive/negative connection checks, DNS TTL old/new comparisons, and standby nginx/DNS migration checks. These outputs were discussed and interpreted as testing proceeded; the complete unaltered console records have not all been committed as separate files.
3. **Uploaded full terminal transcript from Saumya's Mac**: explicitly includes a backup DNS cutover probe returning `10.7.21.149`, restoration to `10.7.12.238`, and DNS service restart; the transcript was supplied in the working conversation, not uploaded here as a standalone evidence file.
4. **Existing Phase 1 evidence**: `evidence/task-g/` contains actual screenshot PNGs showing packet analysis. Do not rename Phase 1 captures as Phase 2 traces.

## Verifiability and limits

- Network configuration files in GitHub are auditable, but do not alone prove that services are running today.
- Summaries in this directory are **transcriptions/paraphrases** of observed tests, not generated Wireshark images or simulated command output.
- Tests without a preserved raw record are explicitly described as needing capture rather than claimed as fully evidenced.
- Faculty-injected troubleshooting cannot be completed before the faculty runs it.
