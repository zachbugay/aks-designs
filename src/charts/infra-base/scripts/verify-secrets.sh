#!/bin/sh
set -e

echo "Waiting for secrets to be synced from Key Vault..."
echo "  Namespace: ${NAMESPACE}"
echo "  Max retries: ${MAX_RETRIES}"
echo "  Retry interval: ${RETRY_INTERVAL}s"

retries=0
while [ "$retries" -lt "$MAX_RETRIES" ]; do
    ca=$(kubectl get secret ca.bundle -n "$NAMESPACE" -o name 2>/dev/null || true)
    tls=$(kubectl get secret gateway-tls-secret -n "$NAMESPACE" -o name 2>/dev/null || true)
    duckdnsToken=$(kubectl get secret duckdns-token -n "$NAMESPACE" -o name 2>/dev/null || true)

    if [ -n "$ca" ] && [ -n "$tls" ] && [ -n "$duckdnsToken" ]; then
        echo "Secrets ca.bundle, gateway-tls-secret, and duckdns-token are available."
        exit 0
    fi

    retries=$((retries + 1))
    echo "Waiting for secrets... ($retries/$MAX_RETRIES)"
    sleep "$RETRY_INTERVAL"
done

echo "ERROR: Timed out waiting for secrets after $((MAX_RETRIES * RETRY_INTERVAL))s."
exit 1
