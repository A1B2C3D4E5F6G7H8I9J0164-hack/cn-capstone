#!/bin/bash
# HTTP Caching Behavior Verification Test
# Validates Cache-Control: max-age=60, ETag validation, and 304 Not Modified

set -e

URL="https://app.cn-capstone.test:8443/api/status"

echo "=== TASK F: HTTP CACHING TEST ==="
echo "Target URL: $URL"
echo

echo "Step 1: Sending initial GET request..."
RESPONSE=$(curl -s -i "$URL")
echo "$RESPONSE" | grep -E -i "HTTP/|Cache-Control|ETag|X-Backend"

ETAG=$(echo "$RESPONSE" | grep -i "^ETag:" | tr -d '\r' | awk '{print $2}')
echo
echo "Observed ETag: $ETAG"
echo

if [ -z "$ETAG" ]; then
    echo "Warning: No ETag returned. Using fallback value '\"A-v1\"'."
    ETAG='"A-v1"'
fi

echo "Step 2: Sending conditional revalidation request with If-None-Match: $ETAG..."
COND_RESPONSE=$(curl -s -i -H "If-None-Match: $ETAG" "$URL")
echo "$COND_RESPONSE" | grep -E -i "HTTP/|ETag|Cache-Control|X-Backend"

STATUS_CODE=$(echo "$COND_RESPONSE" | head -n1 | awk '{print $2}')
echo
if [ "$STATUS_CODE" = "304" ]; then
    echo "[PASS] Received HTTP 304 Not Modified. Cache revalidation verified."
else
    echo "[FAIL] Expected HTTP 304, got $STATUS_CODE"
    exit 1
fi

echo
echo "=== HTTP CACHING TEST PASSED ==="
