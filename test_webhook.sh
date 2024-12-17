#!/bin/bash

# Base URL
URL="http://localhost:3000/webhook"
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

# Test 2: Invalid signature
echo "Test 2: Invalid signature"
curl -i -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=invalid" \
  -d "$PAYLOAD"
echo -e "\n\n"

# Test 3: Missing signature
echo "Test 3: Missing signature"
curl -i -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
echo -e "\n\n" 