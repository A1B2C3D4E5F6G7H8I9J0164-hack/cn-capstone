#!/bin/bash

set -e

URL="https://app.cn-capstone.test:8443/api/status"

echo "=== LOAD BALANCING TEST ==="
echo "URL: $URL"
echo

for i in {1..20}; do
    printf "Request %02d: " "$i"
    curl -s -D - "$URL" -o /dev/null | grep -i "^X-Backend:"
done

echo
echo "=== LOAD BALANCING TEST COMPLETE ==="
