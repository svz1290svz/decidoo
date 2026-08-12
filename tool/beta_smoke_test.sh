#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${API_BASE_URL:?API_BASE_URL is required}"
API_BASE_URL="${API_BASE_URL%/}"

curl --fail --silent --show-error "$API_BASE_URL/health" | grep -q '"status":"ok"'
curl --fail --silent --show-error "$API_BASE_URL/ready" | grep -q '"ready":true'
curl --fail --silent --show-error "$API_BASE_URL/v1" | grep -q 'Decidoo API'

echo "Closed beta API smoke test passed: $API_BASE_URL"
