#!/bin/bash

set -e

URL="https://app.cn-capstone.test:8443/api/status"

echo "=== LOAD BALANCING TEST ==="
echo "URL: $URL"
echo

A_COUNT=0
B_COUNT=0

for i in {1..20}; do
    BACKEND=$(curl -s -D - "$URL" -o /dev/null | grep -i "^X-Backend:" | tr -d '\r' | awk '{print $2}')

    printf "Request %02d: X-Backend: %s\n" "$i" "$BACKEND"

    if [ "$BACKEND" = "A" ]; then
        A_COUNT=$((A_COUNT + 1))
    elif [ "$BACKEND" = "B" ]; then
        B_COUNT=$((B_COUNT + 1))
    fi
done

echo
echo "Backend A responses: $A_COUNT"
echo "Backend B responses: $B_COUNT"

if [ "$A_COUNT" -eq 0 ] || [ "$B_COUNT" -eq 0 ]; then
    echo
    echo "ERROR: Both backends were not observed."
    exit 1
fi

echo
echo "=== LOAD BALANCING TEST PASSED ==="
