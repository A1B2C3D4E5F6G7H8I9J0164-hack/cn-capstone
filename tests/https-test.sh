#!/bin/bash

set -e

URL="https://app.cn-capstone.test:8443/api/status"

echo "=== HTTPS TEST ==="
echo "URL: $URL"
echo

curl -i "$URL"

echo
echo "=== HTTPS TEST PASSED ==="
