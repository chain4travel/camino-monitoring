#!/bin/bash
# export-grafana-alerts.sh
# Exports Grafana alerts, contact points, and notification policies to YAML files

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_AUTH="${GRAFANA_AUTH:-admin:admin}"
OUTPUT_DIR="${OUTPUT_DIR:-./grafana-export}"

# Check if custom auth was provided as argument
if [ -n "$1" ]; then
    GRAFANA_AUTH="$1"
fi

mkdir -p "$OUTPUT_DIR"

echo "Grafana Alert Exporter"
echo "======================"
echo "URL: $GRAFANA_URL"
echo "Output: $OUTPUT_DIR"
echo ""

echo "Exporting alert rules..."
curl -s -u "$GRAFANA_AUTH" \
  -H "Accept: application/yaml" \
  "$GRAFANA_URL/api/v1/provisioning/alert-rules/export" > "$OUTPUT_DIR/alert-rules.yaml" 2>/dev/null || \
  curl -s -u "$GRAFANA_AUTH" \
  "$GRAFANA_URL/api/v1/provisioning/alert-rules" | python3 -c 'import sys, json, yaml; yaml.dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)' > "$OUTPUT_DIR/alert-rules.yaml" 2>/dev/null || \
  echo "Failed to export alert rules"

echo "Exporting contact points..."
curl -s -u "$GRAFANA_AUTH" \
  -H "Accept: application/yaml" \
  "$GRAFANA_URL/api/v1/provisioning/contact-points/export" > "$OUTPUT_DIR/contact-points.yaml" 2>/dev/null || \
  curl -s -u "$GRAFANA_AUTH" \
  "$GRAFANA_URL/api/v1/provisioning/contact-points" | python3 -c 'import sys, json, yaml; yaml.dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)' > "$OUTPUT_DIR/contact-points.yaml" 2>/dev/null || \
  echo "Failed to export contact points"

echo "Exporting notification policies..."
curl -s -u "$GRAFANA_AUTH" \
  -H "Accept: application/yaml" \
  "$GRAFANA_URL/api/v1/provisioning/policies/export" > "$OUTPUT_DIR/notification-policies.yaml" 2>/dev/null || \
  curl -s -u "$GRAFANA_AUTH" \
  "$GRAFANA_URL/api/v1/provisioning/policies" | python3 -c 'import sys, json, yaml; yaml.dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)' > "$OUTPUT_DIR/notification-policies.yaml" 2>/dev/null || \
  echo "Failed to export notification policies"

echo "Exporting mute timings..."
curl -s -u "$GRAFANA_AUTH" \
  -H "Accept: application/yaml" \
  "$GRAFANA_URL/api/v1/provisioning/mute-timings/export" > "$OUTPUT_DIR/mute-timings.yaml" 2>/dev/null || \
  echo "No mute timings or failed to export"

echo "Exporting templates..."
curl -s -u "$GRAFANA_AUTH" \
  -H "Accept: application/yaml" \
  "$GRAFANA_URL/api/v1/provisioning/templates/export" > "$OUTPUT_DIR/templates.yaml" 2>/dev/null || \
  echo "No templates or failed to export"

# Also export as JSON for backup
echo ""
echo "Exporting JSON backups..."
curl -s -u "$GRAFANA_AUTH" "$GRAFANA_URL/api/v1/provisioning/alert-rules" > "$OUTPUT_DIR/alert-rules.json" 2>/dev/null || true
curl -s -u "$GRAFANA_AUTH" "$GRAFANA_URL/api/v1/provisioning/contact-points" > "$OUTPUT_DIR/contact-points.json" 2>/dev/null || true
curl -s -u "$GRAFANA_AUTH" "$GRAFANA_URL/api/v1/provisioning/policies" > "$OUTPUT_DIR/notification-policies.json" 2>/dev/null || true

echo ""
echo "Done! Files saved in $OUTPUT_DIR/"
echo ""
ls -lh "$OUTPUT_DIR/"
echo ""
echo "To use on new machine, copy these files to /etc/grafana/provisioning/alerting/"


