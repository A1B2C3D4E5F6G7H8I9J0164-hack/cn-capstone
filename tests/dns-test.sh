#!/bin/bash
# DNS Resolution Verification Test
# Tests resolution of app.cn-capstone.test via the private DNS server

set -e

DOMAIN="app.cn-capstone.test"
EXPECTED_IP="10.7.5.53"

echo "=== DNS RESOLUTION TEST ==="
echo "Target Domain: $DOMAIN"
echo "Expected IP:   $EXPECTED_IP"
echo

echo "1. Testing resolution via system resolver..."
RESOLVED_IP=$(dig +short "$DOMAIN" | tail -n1)
echo "Resolved IP: $RESOLVED_IP"

if [ "$RESOLVED_IP" = "$EXPECTED_IP" ]; then
    echo "[PASS] Domain correctly resolved to Mac 2 Edge ($EXPECTED_IP)"
else
    echo "[FAIL] Expected $EXPECTED_IP, but got '$RESOLVED_IP'"
    echo "Check if Mac 1 DNS is running and configured in Network Preferences."
    exit 1
fi

echo
echo "2. Testing query response flags and TTL..."
dig "$DOMAIN" | grep -E -A 2 "ANSWER SECTION|flags:"

echo
echo "=== DNS TEST PASSED ==="
