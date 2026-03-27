#!/bin/sh

echo "Initializing Keycloak realm: ${REALM_NAME}"
echo "  Keycloak URL: ${KEYCLOAK_URL}"

# --- Authenticate ---
echo "Authenticating to Keycloak..."
TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=admin-cli&username=${ADMIN_USER}&password=${ADMIN_PASSWORD}" \
    | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to authenticate to Keycloak"
    exit 1
fi
echo "  Authenticated as ${ADMIN_USER}"

AUTH="Authorization: Bearer ${TOKEN}"

# --- Create realm (idempotent) ---
echo "Creating realm '${REALM_NAME}'..."
EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "$AUTH" "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}")

if [ "$EXISTS" = "200" ]; then
    echo "  Realm already exists, skipping."
else
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d "{\"realm\":\"${REALM_NAME}\",\"enabled\":true}"
    echo "  Realm '${REALM_NAME}' created."
fi

# --- Create weather-app client (confidential) ---
echo "Creating client 'weather-app'..."
WA_EXISTS=$(curl -s -H "$AUTH" \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=weather-app" \
    | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)

if [ -n "$WA_EXISTS" ]; then
    echo "  Client 'weather-app' already exists, skipping."
    WA_ID="$WA_EXISTS"
else
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d '{
            "clientId": "weather-app",
            "name": "Weather App",
            "enabled": true,
            "publicClient": false,
            "clientAuthenticatorType": "client-secret",
            "standardFlowEnabled": true,
            "serviceAccountsEnabled": true,
            "redirectUris": ["/*"],
            "webOrigins": ["/*"],
            "directAccessGrantsEnabled": false,
            "implicitFlowEnabled": false
        }'
    WA_ID=$(curl -s -H "$AUTH" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=weather-app" \
        | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
    echo "  Client 'weather-app' created."
fi

if [ -z "$WA_ID" ]; then
    echo "WARNING: Could not resolve 'weather-app' client ID, skipping mapper setup."
else
    # --- Add audience mapper to weather-app ---
    echo "Adding audience mapper to 'weather-app'..."
    MAPPER_EXISTS=$(curl -s -H "$AUTH" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${WA_ID}/protocol-mappers/models" \
        | grep -c 'weather-app-aud' || true)

    if [ "$MAPPER_EXISTS" -gt 0 ]; then
        echo "  Mapper already exists, skipping."
    else
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${WA_ID}/protocol-mappers/models" \
            -H "$AUTH" -H "Content-Type: application/json" \
            -d '{
                "name": "weather-app-aud",
                "protocol": "openid-connect",
                "protocolMapper": "oidc-audience-mapper",
                "config": {
                    "included.client.audience": "weather-app",
                    "id.token.claim": "true",
                    "access.token.claim": "true",
                    "introspection.token.claim": "true"
                }
            }'
        echo "  Audience mapper created."
    fi
fi

# --- Create react-app client (public) ---
echo "Creating client 'react-app'..."
RA_EXISTS=$(curl -s -H "$AUTH" \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=react-app" \
    | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)

if [ -n "$RA_EXISTS" ]; then
    echo "  Client 'react-app' already exists, skipping."
    RA_ID="$RA_EXISTS"
else
    REDIRECT_URIS="[\"http://localhost:5713/*\",\"https://${APP_HOSTNAME}/*\"]"
    WEB_ORIGINS="[\"http://localhost:5713\",\"https://${APP_HOSTNAME}\"]"
    POST_LOGOUT="http://localhost:5713/*##https://${APP_HOSTNAME}/*"

    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d "{
            \"clientId\": \"react-app\",
            \"name\": \"React App\",
            \"enabled\": true,
            \"publicClient\": true,
            \"standardFlowEnabled\": true,
            \"directAccessGrantsEnabled\": false,
            \"implicitFlowEnabled\": false,
            \"serviceAccountsEnabled\": false,
            \"frontchannelLogout\": true,
            \"redirectUris\": ${REDIRECT_URIS},
            \"webOrigins\": ${WEB_ORIGINS},
            \"attributes\": {
                \"pkce.code.challenge.method\": \"S256\",
                \"oauth2.device.authorization.grant.enabled\": \"true\",
                \"post.logout.redirect.uris\": \"${POST_LOGOUT}\",
                \"frontchannel.logout.session.required\": \"true\"
            }
        }"
    RA_ID=$(curl -s -H "$AUTH" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=react-app" \
        | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
    echo "  Client 'react-app' created."
fi

if [ -z "$RA_ID" ]; then
    echo "WARNING: Could not resolve 'react-app' client ID, skipping mapper setup."
else
    # --- Add audience mapper to react-app ---
    echo "Adding audience mapper to 'react-app'..."
    RA_MAPPER_EXISTS=$(curl -s -H "$AUTH" \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${RA_ID}/protocol-mappers/models" \
        | grep -c 'weather-app-aud' || true)

    if [ "$RA_MAPPER_EXISTS" -gt 0 ]; then
        echo "  Mapper already exists, skipping."
    else
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${RA_ID}/protocol-mappers/models" \
            -H "$AUTH" -H "Content-Type: application/json" \
            -d '{
                "name": "weather-app-aud",
                "protocol": "openid-connect",
                "protocolMapper": "oidc-audience-mapper",
                "config": {
                    "included.client.audience": "weather-app",
                    "id.token.claim": "true",
                    "access.token.claim": "true",
                    "introspection.token.claim": "true"
                }
            }'
        echo "  Audience mapper created."
    fi
fi

# --- Create test user (idempotent) ---
echo "Creating user 'user1'..."
USER_EXISTS=$(curl -s -H "$AUTH" \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users?username=user1&exact=true" \
    | grep -c '"username":"user1"' || true)

if [ "$USER_EXISTS" -gt 0 ]; then
    echo "  User 'user1' already exists, skipping."
else
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d '{
            "username": "user1",
            "email": "user1@example.com",
            "emailVerified": true,
            "enabled": true,
            "requiredActions": [],
            "credentials": [{"type":"password","value":"password","temporary":false}]
        }'
    echo "  User 'user1' created."
fi

echo ""
echo "Keycloak realm '${REALM_NAME}' initialization complete."
