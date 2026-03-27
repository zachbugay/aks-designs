#!/bin/sh
set -e

echo "Updating DuckDNS records..."
echo "  Gateway: ${GATEWAY_NAME} in namespace ${GATEWAY_NAMESPACE}"
echo "  Hostnames: ${DUCKDNS_HOSTNAMES}"

# --- Wait for Gateway to have an external IP ---
echo "Waiting for Gateway external IP..."
retries=0
max_retries=120
GATEWAY_IP=""

while [ "$retries" -lt "$max_retries" ]; do
    GATEWAY_IP=$(kubectl get gateway "$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" \
        -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)

    if [ -n "$GATEWAY_IP" ]; then
        # Check if it's already an IP address
        if echo "$GATEWAY_IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            echo "  Gateway IP: $GATEWAY_IP"
            break
        fi
        # It might be a hostname, try to resolve it
        RESOLVED=$(nslookup "$GATEWAY_IP" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || true)
        if [ -n "$RESOLVED" ]; then
            GATEWAY_IP="$RESOLVED"
            echo "  Gateway IP (resolved): $GATEWAY_IP"
            break
        fi
    fi

    retries=$((retries + 1))
    echo "  Waiting for IP... ($retries/$max_retries)"
    sleep 5
done

if [ -z "$GATEWAY_IP" ]; then
    echo "ERROR: Timed out waiting for Gateway external IP."
    exit 1
fi

# --- Update DuckDNS for each hostname ---
IFS=',' ; set -- $DUCKDNS_HOSTNAMES
for hostname in "$@"; do
    # Extract subdomain (strip .duckdns.org)
    subdomain=$(echo "$hostname" | sed 's/\.duckdns\.org$//')
    echo "  Updating $subdomain -> $GATEWAY_IP"

    result=$(curl -sf "https://www.duckdns.org/update?domains=${subdomain}&token=${DUCKDNS_TOKEN}&ip=${GATEWAY_IP}&verbose=true" || true)
    status=$(echo "$result" | head -1)

    if [ "$status" = "OK" ]; then
        echo "  $subdomain updated successfully."
    else
        echo "  WARNING: DuckDNS update for $subdomain returned: $result"
    fi
done

echo ""
echo "DuckDNS update complete."
