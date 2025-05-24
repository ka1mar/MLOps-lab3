#!/bin/bash
set -e

VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
VAULT_TOKEN=${VAULT_DEV_ROOT_TOKEN_ID}
HOST=${HOST}
PORT=${PORT}
DBNAME=${DBNAME}
USER=${USER}
PASSWORD=${PASSWORD}


check_vault() {
  echo "Checking if Vault is ready..."
  local max_retries=10
  local retry=0
  local status=1
  
  while [ $retry -lt $max_retries ] && [ $status -ne 0 ]; do
    curl -s -o /dev/null -w "%{http_code}" $VAULT_ADDR/v1/sys/health > /dev/null 2>&1
    status=$?
    
    if [ $status -ne 0 ]; then
      retry=$((retry+1))
      echo "Vault not ready yet. Retry $retry of $max_retries..."
      sleep 5
    fi
  done
  
  if [ $status -ne 0 ]; then
    echo "Error: Vault is not available after $max_retries retries."
    exit 1
  fi
  
  echo "Vault is ready!"
}

echo "Waiting for Vault to start up... ($WAIT_TIME seconds)"

check_vault

echo "Enabling KV secrets engine at path 'db'..."
curl -s \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --request POST \
  --data '{"type": "kv"}' \
  $VAULT_ADDR/v1/sys/mounts/db || {
    echo "The KV secrets engine might already be enabled at path 'db'"
  }

echo "Storing database credentials..."
curl -s \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --request POST \
  --data "{\"host\":\"$HOST\", \"port\":\"$PORT\", \"dbname\":\"$DBNAME\", \"user\":\"$USER\", \"password\":\"$PASSWORD\"}" \
  $VAULT_ADDR/v1/db/data

echo "Verifying secrets..."
RESPONSE=$(curl -s \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/db/data)

if echo "$RESPONSE" | grep -q "\"host\":\"$HOST\""; then
  echo "Success! Database credentials stored in Vault."
else
  echo "Warning: Could not verify if credentials were stored correctly."
  echo "Response: $RESPONSE"
fi

echo "Vault setup completed."