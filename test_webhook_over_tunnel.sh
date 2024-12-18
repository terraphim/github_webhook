#!/bin/bash

# Base URL
URL="https://rare-prep-major-dining.trycloudflare.com/webhook"
SECRET="secret"

# Test payload
PAYLOAD='{"action":"opened","number":1,"pull_request":{"title":"Test PR","html_url":"https://github.com/user/repo/pull/1"}}'

# Generate signature
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -hex | sed 's/^.* //')

# Test 1: Valid request
echo "Test 1: Valid request"
curl -i -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIGNATURE" \
  -d "$PAYLOAD"
echo -e "\n\n"