#!/bin/bash
SCRAPING_INTERVAL=15
PUSH_GATEWAY_URL_PORT=${1}
VALIDATORS_API_URL=${2}

query_validators_status() {
  response=$(curl -s -w "%{http_code}" -X POST -H "Content-type: application/json" ${VALIDATORS_API_URL}/ext/bc/P -d '{"jsonrpc": "2.0","method": "platform.getCurrentValidators","params": {},"id": 1}')
  status_code=$(tail -n1 <<<"$response") # get the last line
  if [[ "$response" == *"\"error\":{\"code\""* ]] || [[ "$status_code" -ne 200 ]]; then
    return 1
  else
    extract_metric_uptime
    extract_metric_connected
    return 0
  fi
}

extract_metric_connected() {
  metric_connected=$(echo $response |
    jq |
    grep connected |
    sed -e 's/"connected": //g' -e 's/,//g' -e 's/^[ ]*//g' |
    sort |
    uniq -c |
    sed 's/true/connected/' |
    sed 's/false/disconnected/' |
    xargs -n 2 echo |
    awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1"\\n";}')

  if [[ ! $metric_connected =~ "disconnected" ]]; then
    metric_connected+="disconnected 0"
  fi
}
extract_metric_uptime() {
  metric_uptime=$(echo $response | sed "s/$status_code//g"|
    jq '.result.validators[] | .nodeID + " " + .uptime' | # select json attributes
    sed 's/"NodeID/uptime{nodeID="NodeID/' | # add metric label prefix
    sed 's/ /"} /g' | # add label suffix
    sed 's/"$//' | # remove trailing quotes
    awk '{ for (i=0; i<1; i++) printf("%s",$i); print "\\n";}')
}

cleanup() {
  echo "ping_validator_status 0" | curl --data-binary @- ${PUSH_GATEWAY_URL_PORT}/metrics/job/validators_status/instance/push_daemon
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
  if query_validators_status; then
    echo "ping_validator_status 1" | curl --data-binary @- ${PUSH_GATEWAY_URL_PORT}/metrics/job/validators_status/instance/push_daemon
    cat <<EOF | curl --data-binary @- ${PUSH_GATEWAY_URL_PORT}/metrics/job/validators_status/instance/push_daemon
    $(echo -e $metric_connected)
    $(echo -e $metric_uptime)
EOF
    echo "Pushing metrics..."
  else
    echo "Failed to collect metrics..."
    cleanup
  fi
  sleep $SCRAPING_INTERVAL
done
