#!/bin/bash
# Comprehensive Camino Monitoring Installer
# Installs Prometheus, Grafana, node_exporter, pushgateway, dashboards, alerts, and push daemons
#
# Usage:
#   ./install-monitoring.sh --network columbus \
#     --discord-webhook "https://discord.com/api/webhooks/..." \
#     --email "tech@chain4travel.com" \
#     --api-url "https://columbus.camino.network" \
#     --internal-api-url "https://internal.columbus.camino.network" \
#     --magellan-url "https://magellan.columbus.camino.network" \
#     --signavault-url "https://signavault.columbus.camino.network"

set -e

# Default values
PUSH_GATEWAY_URL_PORT="localhost:9091"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Usage help
usage() {
  cat << EOF
Camino Monitoring Installer
============================

Usage: $0 [OPTIONS]

Required Options:
  --network <name>           Network name: 'camino' (mainnet) or 'columbus' (testnet)
  --discord-webhook <url>    Discord webhook URL for alerts
  --email <address>          Email address for alerts
  --api-url <url>            Public API URL (e.g., https://columbus.camino.network)
  --internal-api-url <url>   Internal API URL (e.g., https://internal.columbus.camino.network)
  --magellan-url <url>       Magellan URL (e.g., https://magellan.columbus.camino.network)
  --signavault-url <url>     Signavault URL (e.g., https://signavault.columbus.camino.network)

Optional Options:
  --skip-prometheus          Skip Prometheus installation
  --skip-grafana             Skip Grafana installation
  --skip-node-exporter       Skip node_exporter installation
  --skip-pushgateway         Skip pushgateway installation
  --skip-dashboards          Skip dashboard installation
  --skip-alerts              Skip alert installation
  --skip-push-daemons        Skip push daemon installation
  --help                     Show this help message

Examples:
  # Full installation for Columbus testnet
  $0 --network columbus \\
     --discord-webhook "https://discord.com/api/webhooks/xxx/yyy" \\
     --email "tech@chain4travel.com" \\
     --api-url "https://columbus.camino.network" \\
     --internal-api-url "https://internal.columbus.camino.network" \\
     --magellan-url "https://magellan.columbus.camino.network" \\
     --signavault-url "https://signavault.columbus.camino.network"

  # Full installation for Camino mainnet
  $0 --network camino \\
     --discord-webhook "https://discord.com/api/webhooks/xxx/yyy" \\
     --email "tech@chain4travel.com" \\
     --api-url "https://api.camino.network" \\
     --internal-api-url "https://internal.api.camino.network" \\
     --magellan-url "https://magellan.camino.network" \\
     --signavault-url "https://signavault.camino.network"
EOF
}

# Parse command line arguments
parse_args() {
  SKIP_PROMETHEUS=false
  SKIP_GRAFANA=false
  SKIP_NODE_EXPORTER=false
  SKIP_PUSHGATEWAY=false
  SKIP_DASHBOARDS=false
  SKIP_ALERTS=false
  SKIP_PUSH_DAEMONS=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --network)
        NETWORK="$2"
        shift 2
        ;;
      --discord-webhook)
        DISCORD_WEBHOOK="$2"
        shift 2
        ;;
      --email)
        EMAIL="$2"
        shift 2
        ;;
      --api-url)
        API_URL="$2"
        shift 2
        ;;
      --internal-api-url)
        INTERNAL_API_URL="$2"
        shift 2
        ;;
      --magellan-url)
        MAGELLAN_URL="$2"
        shift 2
        ;;
      --signavault-url)
        SIGNAVAULT_URL="$2"
        shift 2
        ;;
      --skip-prometheus)
        SKIP_PROMETHEUS=true
        shift
        ;;
      --skip-grafana)
        SKIP_GRAFANA=true
        shift
        ;;
      --skip-node-exporter)
        SKIP_NODE_EXPORTER=true
        shift
        ;;
      --skip-pushgateway)
        SKIP_PUSHGATEWAY=true
        shift
        ;;
      --skip-dashboards)
        SKIP_DASHBOARDS=true
        shift
        ;;
      --skip-alerts)
        SKIP_ALERTS=true
        shift
        ;;
      --skip-push-daemons)
        SKIP_PUSH_DAEMONS=true
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        print_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Validate required arguments
  if [[ -z "$NETWORK" ]]; then
    print_error "Missing required argument: --network"
    usage
    exit 1
  fi

  if [[ "$NETWORK" != "camino" && "$NETWORK" != "columbus" ]]; then
    print_error "Network must be 'camino' or 'columbus'"
    exit 1
  fi

  # Set environment label based on network
  if [[ "$NETWORK" == "camino" ]]; then
    ENV_LABEL="mainnet"
  else
    ENV_LABEL="testnet"
  fi

  if [[ -z "$DISCORD_WEBHOOK" ]]; then
    print_error "Missing required argument: --discord-webhook"
    usage
    exit 1
  fi

  if [[ -z "$EMAIL" ]]; then
    print_error "Missing required argument: --email"
    usage
    exit 1
  fi

  if [[ -z "$API_URL" ]]; then
    print_error "Missing required argument: --api-url"
    usage
    exit 1
  fi

  if [[ -z "$INTERNAL_API_URL" ]]; then
    print_error "Missing required argument: --internal-api-url"
    usage
    exit 1
  fi

  if [[ -z "$MAGELLAN_URL" ]]; then
    print_error "Missing required argument: --magellan-url"
    usage
    exit 1
  fi

  if [[ -z "$SIGNAVAULT_URL" ]]; then
    print_error "Missing required argument: --signavault-url"
    usage
    exit 1
  fi
}

# Check system requirements
check_requirements() {
  print_info "Checking system requirements..."

  if ((EUID == 0)); then
    print_error "This script should not be run as root. Please run without sudo."
    exit 1
  fi

  # Check for required commands
  for cmd in curl wget jq; do
    if ! command -v $cmd &>/dev/null; then
      print_info "Installing $cmd..."
      sudo apt-get update -qq
      sudo apt-get install -y $cmd
    fi
  done

  # Get system architecture
  foundArch="$(uname -m)"
  foundOS="$(uname)"

  if [ "$foundOS" != "Linux" ]; then
    print_error "Unsupported operating system: $foundOS"
    exit 1
  fi

  if [ "$foundArch" = "aarch64" ]; then
    ARCH="arm64"
  elif [ "$foundArch" = "x86_64" ]; then
    ARCH="amd64"
  else
    print_error "Unsupported architecture: $foundArch"
    exit 1
  fi

  print_info "System: $foundOS $ARCH"
}

# Install Prometheus
install_prometheus() {
  if [[ "$SKIP_PROMETHEUS" == true ]]; then
    print_info "Skipping Prometheus installation..."
    return
  fi

  print_info "Installing Prometheus..."
  
  mkdir -p /tmp/camino-monitoring-installer/prometheus
  cd /tmp/camino-monitoring-installer/prometheus

  # Get latest Prometheus version
  promFileName="$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep -o "http.*linux-${ARCH}\.tar\.gz" | head -1)"
  
  if [[ -z "$promFileName" ]]; then
    print_error "Unable to find Prometheus download URL"
    exit 1
  fi

  print_info "Downloading: $promFileName"
  wget -nv --show-progress -O prometheus.tar.gz "$promFileName"
  
  mkdir -p prometheus
  tar xf prometheus.tar.gz -C prometheus --strip-components=1
  
  # Create prometheus user
  sudo useradd -M -r -s /bin/false prometheus 2>/dev/null || true
  
  # Create directories
  sudo mkdir -p /etc/prometheus /var/lib/prometheus
  
  cd prometheus
  sudo cp prometheus promtool /usr/local/bin/
  sudo chown prometheus:prometheus /usr/local/bin/{prometheus,promtool}
  
  # Copy console files if they exist
  if [[ -d consoles ]]; then
    sudo cp -r consoles /etc/prometheus/
  fi
  if [[ -d console_libraries ]]; then
    sudo cp -r console_libraries /etc/prometheus/
  fi
  
  sudo cp prometheus.yml /etc/prometheus/
  sudo chown -R prometheus:prometheus /etc/prometheus
  sudo chown prometheus:prometheus /var/lib/prometheus

  # Create systemd service
  cat << 'EOF' | sudo tee /etc/systemd/system/prometheus.service > /dev/null
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.external-url=

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl start prometheus
  sudo systemctl enable prometheus

  print_info "Prometheus installed successfully!"
}

# Install Grafana
install_grafana() {
  if [[ "$SKIP_GRAFANA" == true ]]; then
    print_info "Skipping Grafana installation..."
    return
  fi

  print_info "Installing Grafana..."
  
  sudo apt-get install -y apt-transport-https software-properties-common
  
  # Add Grafana GPG key
  sudo mkdir -p /etc/apt/keyrings/
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
  
  # Add Grafana repository
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
  
  sudo apt-get update -y
  sudo apt-get install -y grafana

  sudo systemctl daemon-reload
  sudo systemctl start grafana-server
  sudo systemctl enable grafana-server

  print_info "Grafana installed successfully!"
}

# Install node_exporter
install_node_exporter() {
  if [[ "$SKIP_NODE_EXPORTER" == true ]]; then
    print_info "Skipping node_exporter installation..."
    return
  fi

  print_info "Installing node_exporter..."
  
  mkdir -p /tmp/camino-monitoring-installer/exporter
  cd /tmp/camino-monitoring-installer/exporter

  nodeFileName="$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep -o "http.*linux-${ARCH}\.tar\.gz" | head -1)"
  
  print_info "Downloading: $nodeFileName"
  wget -nv --show-progress -O node_exporter.tar.gz "$nodeFileName"
  
  tar xf node_exporter.tar.gz --strip-components=1
  sudo mv node_exporter /usr/local/bin/

  # Create systemd service
  cat << 'EOF' | sudo tee /etc/systemd/system/node_exporter.service > /dev/null
[Unit]
Description=Node exporter
Documentation=https://github.com/prometheus/node_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/node_exporter \
    --collector.cpu \
    --collector.diskstats \
    --collector.filesystem \
    --collector.loadavg \
    --collector.meminfo \
    --collector.filefd \
    --collector.netdev \
    --collector.stat \
    --collector.netstat \
    --collector.systemd \
    --collector.uname \
    --collector.vmstat \
    --collector.time \
    --collector.mdadm \
    --collector.zfs \
    --collector.tcpstat \
    --collector.bonding \
    --collector.hwmon \
    --collector.arp \
    --web.listen-address=:9100 \
    --web.telemetry-path="/metrics"

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl start node_exporter
  sudo systemctl enable node_exporter

  # Update prometheus.yml with scrape configs
  # Extract hostname from API_URL for caminogo job
  API_HOST=$(echo "${API_URL}" | sed -e 's|^https\?://||' -e 's|/.*$||')
  INTERNAL_API_HOST=$(echo "${INTERNAL_API_URL}" | sed -e 's|^https\?://||' -e 's|/.*$||')
  
  cat << EOF | sudo tee -a /etc/prometheus/prometheus.yml > /dev/null

  - job_name: 'caminogo'
    metrics_path: '/ext/metrics'
    scheme: https
    static_configs:
      - targets: ['${INTERNAL_API_HOST}']

  - job_name: 'caminogo-machine'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          alias: 'machine'

  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['${PUSH_GATEWAY_URL_PORT}']
EOF

  sudo systemctl restart prometheus

  print_info "node_exporter installed successfully!"
}

# Install pushgateway
install_pushgateway() {
  if [[ "$SKIP_PUSHGATEWAY" == true ]]; then
    print_info "Skipping pushgateway installation..."
    return
  fi

  print_info "Installing Prometheus Pushgateway..."
  
  mkdir -p /tmp/camino-monitoring-installer/pushgateway
  cd /tmp/camino-monitoring-installer/pushgateway

  promFileName="$(curl -s https://api.github.com/repos/prometheus/pushgateway/releases/latest | grep -o "http.*linux-${ARCH}\.tar\.gz" | head -1)"
  
  print_info "Downloading: $promFileName"
  wget -nv --show-progress -O pushgateway.tar.gz "$promFileName"
  
  tar xf pushgateway.tar.gz --strip-components=1
  sudo mv pushgateway /usr/local/bin/

  # Create systemd service
  cat << 'EOF' | sudo tee /etc/systemd/system/pushgateway.service > /dev/null
[Unit]
Description=Prometheus Pushgateway
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/pushgateway

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl start pushgateway
  sudo systemctl enable pushgateway

  print_info "Pushgateway installed successfully!"
}

# Install dashboards
install_dashboards() {
  if [[ "$SKIP_DASHBOARDS" == true ]]; then
    print_info "Skipping dashboard installation..."
    return
  fi

  print_info "Installing Grafana dashboards..."
  
  sudo mkdir -p /etc/grafana/dashboards
  
  # Copy dashboards from script directory
  for dashboard in c_chain.json database.json machine.json main.json network.json p_chain.json x_chain.json subnets.json; do
    if [[ -f "$SCRIPT_DIR/dashboards/$dashboard" ]]; then
      sudo cp "$SCRIPT_DIR/dashboards/$dashboard" /etc/grafana/dashboards/
    fi
  done

  # Create dashboard provisioning config
  cat << 'EOF' | sudo tee /etc/grafana/provisioning/dashboards/camino.yaml > /dev/null
apiVersion: 1

providers:
  - name: 'Camino official'
    orgId: 1
    folder: ''
    folderUid: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /etc/grafana/dashboards
      foldersFromFilesStructure: true
EOF

  # Create datasource provisioning config
  cat << 'EOF' | sudo tee /etc/grafana/provisioning/datasources/prometheus.yaml > /dev/null
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: http://localhost:9090
    isDefault: true
    version: 1
    editable: false
    uid: PBFA97CFB590B2093
EOF

  print_info "Dashboards installed successfully!"
}

# Install alerts and contact points
install_alerts() {
  if [[ "$SKIP_ALERTS" == true ]]; then
    print_info "Skipping alert installation..."
    return
  fi

  print_info "Installing alerts and contact points..."
  
  sudo mkdir -p /etc/grafana/provisioning/alerting

  # Escape special characters in Discord webhook URL for sed
  DISCORD_WEBHOOK_ESCAPED=$(echo "$DISCORD_WEBHOOK" | sed 's/[&/\]/\\&/g')
  EMAIL_ESCAPED=$(echo "$EMAIL" | sed 's/[&/\]/\\&/g')

  # Copy and configure contact points
  for contact_file in "$SCRIPT_DIR"/contact-points/*.yaml; do
    if [[ -f "$contact_file" ]]; then
      filename=$(basename "$contact_file")
      sed "s/__DISCORD_WEBHOOK__/${DISCORD_WEBHOOK_ESCAPED}/g; s/__EMAIL__/${EMAIL_ESCAPED}/g" "$contact_file" | \
        sudo tee "/etc/grafana/provisioning/alerting/contact-$filename" > /dev/null
    fi
  done

  # Copy notification policies
  for policy_file in "$SCRIPT_DIR"/notification-policies/*.yaml; do
    if [[ -f "$policy_file" ]]; then
      filename=$(basename "$policy_file")
      sudo cp "$policy_file" "/etc/grafana/provisioning/alerting/policy-$filename"
    fi
  done

  # Copy alert rules and update placeholders
  for alert_file in "$SCRIPT_DIR"/alerts/*.yaml; do
    if [[ -f "$alert_file" ]]; then
      filename=$(basename "$alert_file")
      # Replace __ENV__ placeholder with correct value
      sed "s/__ENV__/${ENV_LABEL}/g" "$alert_file" | \
        sudo tee "/etc/grafana/provisioning/alerting/alert-$filename" > /dev/null
    fi
  done

  print_info "Alerts and contact points installed successfully!"
}

# Install push daemons
install_push_daemons() {
  if [[ "$SKIP_PUSH_DAEMONS" == true ]]; then
    print_info "Skipping push daemon installation..."
    return
  fi

  print_info "Installing push daemons..."

  # Copy push scripts
  sudo cp "$SCRIPT_DIR/push_validators_status.sh" /usr/local/bin/
  sudo cp "$SCRIPT_DIR/push_health_status.sh" /usr/local/bin/
  sudo chmod +x /usr/local/bin/push_validators_status.sh
  sudo chmod +x /usr/local/bin/push_health_status.sh

  # Create push_validators_status service
  cat << EOF | sudo tee /etc/systemd/system/push_validators_status.service > /dev/null
[Unit]
Description=Push validators status exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/push_validators_status.sh ${PUSH_GATEWAY_URL_PORT} ${API_URL}
ExecStop=/usr/local/bin/push_validators_status.sh ${PUSH_GATEWAY_URL_PORT} ${API_URL} cleanup
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  # Create push_health_status service
  cat << EOF | sudo tee /etc/systemd/system/push_health_status.service > /dev/null
[Unit]
Description=Push health status exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/push_health_status.sh ${PUSH_GATEWAY_URL_PORT} ${API_URL} ${INTERNAL_API_URL} ${MAGELLAN_URL} ${SIGNAVAULT_URL}
ExecStop=/usr/local/bin/push_health_status.sh ${PUSH_GATEWAY_URL_PORT} ${API_URL} ${INTERNAL_API_URL} ${MAGELLAN_URL} ${SIGNAVAULT_URL} cleanup
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl start push_validators_status
  sudo systemctl enable push_validators_status
  sudo systemctl start push_health_status
  sudo systemctl enable push_health_status

  print_info "Push daemons installed successfully!"
}

# Restart Grafana to apply all changes
restart_grafana() {
  print_info "Restarting Grafana to apply changes..."
  sudo systemctl restart grafana-server
}

# Cleanup temporary files
cleanup() {
  print_info "Cleaning up temporary files..."
  rm -rf /tmp/camino-monitoring-installer
}

# Print summary
print_summary() {
  echo ""
  echo "========================================"
  echo "  Installation Complete!"
  echo "========================================"
  echo ""
  echo "Network:       ${NETWORK} (${ENV_LABEL})"
  echo "API URL:       ${API_URL}"
  echo "Internal API:  ${INTERNAL_API_URL}"
  echo "Magellan URL:  ${MAGELLAN_URL}"
  echo "Signavault:    ${SIGNAVAULT_URL}"
  echo ""
  echo "Services:"
  echo "  - Prometheus:   http://localhost:9090"
  echo "  - Grafana:      http://localhost:3000 (admin/admin)"
  echo "  - Pushgateway:  http://localhost:9091"
  echo ""
  echo "Check service status:"
  echo "  sudo systemctl status prometheus"
  echo "  sudo systemctl status grafana-server"
  echo "  sudo systemctl status node_exporter"
  echo "  sudo systemctl status pushgateway"
  echo "  sudo systemctl status push_validators_status"
  echo "  sudo systemctl status push_health_status"
  echo ""
}

# Main execution
main() {
  echo ""
  echo "========================================"
  echo "  Camino Monitoring Installer"
  echo "========================================"
  echo ""

  parse_args "$@"
  check_requirements

  install_prometheus
  install_grafana
  install_node_exporter
  install_pushgateway
  install_dashboards
  install_alerts
  install_push_daemons
  restart_grafana
  cleanup
  print_summary
}

main "$@"

