#!/bin/bash
SCRAPING_INTERVAL=15
PUSH_GATEWAY_URL_PORT=${1}
VALIDATORS_API_URL=${2}

query_health_status() {
  response=$(curl -s -w "%{http_code}" -X POST -H "Content-type: application/json" $VALIDATORS_API_URL/ext/info -d '{"jsonrpc": "2.0","method": "info.getNetworkName","id": 1}')
  status_code=$(tail -n1 <<<"$response") # get the last line
  if [[ "$response" == *"\"error\":{\"code\""* ]] || [[ "$status_code" -ne 200 ]]; then
    return 1
  else
    network_name=$(echo $response | sed 's/...$//' | jq -r .result.networkName)
    if [[ $network_name == "camino" ]]
    then
      public_api_url="https://api.camino.network"
      internal_api_url="https://internal.api.camino.network"
      magellan_url="https://magellan.camino.network"
      signavault_url="https://signavault.camino.network/v1/deposit-offer/QBjybaWQ9FdyQ4gc1cNts3dgmPN8ga32r?signature=765e1324d476f83c0887d8144579c734651800006b55c85d191e890e78168f1c417da2fd03d71af2cf52d9cb16c5554b90a08185dc268c6eb917c3e47085f00801&timestamp=1715169776&multisig=false"
    elif [[ $network_name == "columbus" ]]
    then
      public_api_url="https://columbus.camino.network"
      internal_api_url="https://internal.columbus.camino.network"
      magellan_url="https://magellan.columbus.camino.network"
      signavault_url="https://signavault.columbus.camino.network/v1/deposit-offer/QBjybaWQ9FdyQ4gc1cNts3dgmPN8ga32r?signature=765e1324d476f83c0887d8144579c734651800006b55c85d191e890e78168f1c417da2fd03d71af2cf52d9cb16c5554b90a08185dc268c6eb917c3e47085f00801&timestamp=1715169776&multisig=false"
    else
      return 1
    fi 
    extract_metric_public_api_healthy
    extract_metric_internal_api_healthy
    extract_metric_magellan_healthy
    extract_metric_signavault_healthy
    echo $metric_public_api_healthy
    echo $metric_internal_api_healthy
    echo $metric_magellan_healthy
    echo $metric_signavault_healthy
    return 0
  fi
}

extract_metric_public_api_healthy() {
  public_api_response=$(curl -s -w "%{http_code}" -X POST -H "Content-type: application/json" $public_api_url/ext/health -d '{"jsonrpc": "2.0","method": "health.health","params": {},"id": 1}')
  public_api_status_code=$(tail -n1 <<<"$public_api_response") # get the last line

  if [[ "$public_api_status_code" -ne 200 ]]
  then
    return 1
  fi
  public_api_healthy=$(echo $public_api_response | sed 's/...$//' | jq .result.healthy)
  if [[ $public_api_healthy == "true" ]]
  then
        metric_public_api_healthy="public_api_health_status 1"
  else
        metric_public_api_healthy="public_api_health_status 0"
  fi 
 
}


extract_metric_internal_api_healthy() {
  internal_api_response=$(curl -s -w "%{http_code}" -X POST -H "Content-type: application/json" $internal_api_url/ext/health -d '{"jsonrpc": "2.0","method": "health.health","params": {},"id": 1}')
  internal_api_status_code=$(tail -n1 <<<"$internal_api_response") # get the last line

  if [[ "$internal_api_status_code" -ne 200 ]]
  then
    return 1
  fi
  internal_api_healthy=$(echo $internal_api_response | sed 's/...$//' | jq .result.healthy)
  if [[ $internal_api_healthy == "true" ]]
  then
        metric_internal_api_healthy="internal_api_health_status 1"
  else
        metric_internal_api_healthy="internal_api_health_status 0"
  fi 
 
}


extract_metric_magellan_healthy() {
  magellan_response=$(curl -s -w "%{http_code}" "$magellan_url/v2")
  magellan_status_code=$(tail -c 4 <<<"$magellan_response") 

  if [[ "$magellan_status_code" -ne 200 ]]
  then
        metric_magellan_healthy="magellan_health_status 0"
  else
        metric_magellan_healthy="magellan_health_status 1"
  fi   
 
}

extract_metric_signavault_healthy() {
  signavault_response=$(curl -s -w "%{http_code}" "$signavault_url")
  signavault_status_code=$(tail -c 4 <<<"$signavault_response") 


  if [[ "$signavault_status_code" -ne 200 ]]
  then
        metric_signavault_healthy="signavault_health_status 0"
  else
        metric_signavault_healthy="signavault_health_status 1"
  fi   
 
}


cleanup() {
  echo "ping_health_status 0" | curl --data-binary @- ${PUSH_GATEWAY_URL_PORT}/metrics/job/health_status/instance/push_daemon
}

if [[ $# -lt 2 ]]; then
  echo 'Required number of arguments: 2'
  echo 'prometheus_url:port validators_api_base_url "cleanup"(optional)'
  exit 1
elif [[ $# -eq 3 ]] && [ "$3" = "cleanup" ]; then
  echo 'Cleaning up...'
  cleanup
  exit 1
fi
while true; do
  if query_health_status; then
    echo "ping_health_status 1" | curl --data-binary @- ${PUSH_GATEWAY_URL_PORT}/metrics/job/health_status/instance/push_daemon
    cat <<EOF | curl --data-binary @- ${PUSH_GATEWAY_URL_PORT}/metrics/job/health_status/instance/push_daemon
    $(echo -e $metric_public_api_healthy)
    $(echo -e $metric_internal_api_healthy)
    $(echo -e $metric_magellan_healthy)
    $(echo -e $metric_signavault_healthy)

EOF
    echo "Pushing metrics..."
  else
    echo "Failed to collect metrics..."
    cleanup
  fi
  sleep $SCRAPING_INTERVAL
done
