#!/bin/sh
set -e

cat > /usr/share/nginx/html/config.json <<EOF
{
  "keycloakUrl": "${KEYCLOAK_URL:-http://localhost:8080}",
  "keycloakRealm": "${KEYCLOAK_REALM:-master}",
  "keycloakClientId": "${KEYCLOAK_CLIENT_ID:-react-app}",
  "apiBaseUrl": "${API_BASE_URL:-http://localhost:5000}"
}
EOF

exec nginx -g "daemon off;"
