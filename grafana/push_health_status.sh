#!/bin/bash
# Push health status metrics to Prometheus Pushgateway
# Usage: push_health_status.sh <pushgateway_url:port> <api_url> <internal_api_url> <magellan_url> <signavault_url> [cleanup]

SCRAPING_INTERVAL=15
PUSH_GATEWAY_URL_PORT=${1}
PUBLIC_API_URL=${2}
INTERNAL_API_URL=${3}
MAGELLAN_URL=${4}
SIGNAVAULT_URL=${5}

# Validate required parameters
validate_params() {
  if [[ -z "$PUSH_GATEWAY_URL_PORT" || -z "$PUBLIC_API_URL" || -z "$INTERNAL_API_URL" || -z "$MAGELLAN_URL" || -z "$SIGNAVAULT_URL" ]]; then
    echo 'Usage: push_health_status.sh <pushgateway_url:port> <api_url> <internal_api_url> <magellan_url> <signavault_url> [cleanup]'
    echo ''
    echo 'Parameters:'
    echo '  pushgateway_url:port  - Pushgateway endpoint (e.g., localhost:9091)'
    echo '  api_url               - Public API URL (e.g., https://columbus.camino.network)'
    echo '  internal_api_url      - Internal API URL (e.g., https://internal.columbus.camino.network)'
    echo '  magellan_url          - Magellan URL (e.g., https://magellan.columbus.camino.network)'
    echo '  signavault_url        - Signavault URL (e.g., https://signavault.columbus.camino.network)'
    echo ''
    echo 'Examples:'
    echo '  # Columbus (testnet)'
    echo '  push_health_status.sh localhost:9091 https://columbus.camino.network https://internal.columbus.camino.network https://magellan.columbus.camino.network https://signavault.columbus.camino.network'
    echo ''
    echo '  # Camino (mainnet)'
    echo '  push_health_status.sh localhost:9091 https://api.camino.network https://internal.api.camino.network https://magellan.camino.network https://signavault.camino.network'
    exit 1
  fi
}

query_health_status() {
  extract_metric_public_api_healthy
  extract_metric_internal_api_healthy
  extract_metric_magellan_healthy
  extract_metric_signavault_healthy
  
  echo "$metric_public_api_healthy"
  echo "$metric_internal_api_healthy"
  echo "$metric_magellan_healthy"
  echo "$metric_signavault_healthy"
  
  return 0
}

extract_metric_public_api_healthy() {
  public_api_response=$(curl -s -w "%{http_code}" -X POST -H "Content-type: application/json" "$PUBLIC_API_URL/ext/health" -d '{"jsonrpc": "2.0","method": "health.health","params": {},"id": 1}')
  public_api_status_code=$(tail -n1 <<<"$public_api_response")

  if [[ "$public_api_status_code" -ne 200 ]]; then
    metric_public_api_healthy="public_api_health_status 0"
    return 1
  fi
  
  public_api_healthy=$(echo "$public_api_response" | sed 's/...$//' | jq .result.healthy)
  if [[ $public_api_healthy == "true" ]]; then
    metric_public_api_healthy="public_api_health_status 1"
  else
    metric_public_api_healthy="public_api_health_status 0"
  fi
}

extract_metric_internal_api_healthy() {
  internal_api_response=$(curl -s -w "%{http_code}" -X POST -H "Content-type: application/json" "$INTERNAL_API_URL/ext/health" -d '{"jsonrpc": "2.0","method": "health.health","params": {},"id": 1}')
  internal_api_status_code=$(tail -n1 <<<"$internal_api_response")

  if [[ "$internal_api_status_code" -ne 200 ]]; then
    metric_internal_api_healthy="internal_api_health_status 0"
    return 1
  fi
  
  internal_api_healthy=$(echo "$internal_api_response" | sed 's/...$//' | jq .result.healthy)
  if [[ $internal_api_healthy == "true" ]]; then
    metric_internal_api_healthy="internal_api_health_status 1"
  else
    metric_internal_api_healthy="internal_api_health_status 0"
  fi
}

extract_metric_magellan_healthy() {
  magellan_response=$(curl -s -w "%{http_code}" "$MAGELLAN_URL/v2")
  magellan_status_code=$(tail -c 4 <<<"$magellan_response")

  if [[ "$magellan_status_code" -ne 200 ]]; then
    metric_magellan_healthy="magellan_health_status 0"
  else
    metric_magellan_healthy="magellan_health_status 1"
  fi
}

extract_metric_signavault_healthy() {
  # Signavault health check URL with test parameters
  signavault_check_url="${SIGNAVAULT_URL}/v1/deposit-offer/QBjybaWQ9FdyQ4gc1cNts3dgmPN8ga32r?signature=765e1324d476f83c0887d8144579c734651800006b55c85d191e890e78168f1c417da2fd03d71af2cf52d9cb16c5554b90a08185dc268c6eb917c3e47085f00801&timestamp=1715169776&multisig=false"
  signavault_response=$(curl -s -w "%{http_code}" "$signavault_check_url")
  signavault_status_code=$(tail -c 4 <<<"$signavault_response")

  if [[ "$signavault_status_code" -ne 200 ]]; then
    metric_signavault_healthy="signavault_health_status 0"
  else
    metric_signavault_healthy="signavault_health_status 1"
  fi
}

cleanup() {
  echo "ping_health_status 0" | curl --data-binary @- "${PUSH_GATEWAY_URL_PORT}/metrics/job/health_status/instance/push_daemon"
}

# Validate parameters
validate_params

# Handle cleanup
if [[ $# -eq 6 ]] && [ "$6" = "cleanup" ]; then
  echo 'Cleaning up...'
  cleanup
  exit 0
fi

# Main loop
while true; do
  if query_health_status; then
    echo "ping_health_status 1" | curl --data-binary @- "${PUSH_GATEWAY_URL_PORT}/metrics/job/health_status/instance/push_daemon"
    cat <<EOF | curl --data-binary @- "${PUSH_GATEWAY_URL_PORT}/metrics/job/health_status/instance/push_daemon"
    $(echo -e "$metric_public_api_healthy")
    $(echo -e "$metric_internal_api_healthy")
    $(echo -e "$metric_magellan_healthy")
    $(echo -e "$metric_signavault_healthy")

EOF
    echo "Pushing metrics..."
  else
    echo "Failed to collect metrics..."
    cleanup
  fi
  sleep $SCRAPING_INTERVAL
done
