# Camino Monitoring

This directory contains scripts and configurations for setting up Prometheus and Grafana monitoring for Camino networks.

## Quick Start

Use the `install-monitoring.sh` script for a complete automated installation:

```bash
# For Columbus (testnet)
./install-monitoring.sh \
  --network columbus \
  --discord-webhook "https://discord.com/api/webhooks/xxx/yyy" \
  --email "tech@chain4travel.com" \
  --api-url "https://columbus.camino.network" \
  --internal-api-url "https://internal.columbus.camino.network"

# For Camino (mainnet)
./install-monitoring.sh \
  --network camino \
  --discord-webhook "https://discord.com/api/webhooks/xxx/yyy" \
  --email "tech@chain4travel.com" \
  --api-url "https://api.camino.network" \
  --internal-api-url "https://internal.api.camino.network"
```

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--network` | Network name | `columbus` (testnet) or `camino` (mainnet) |
| `--discord-webhook` | Discord webhook URL for alerts | `https://discord.com/api/webhooks/...` |
| `--email` | Email address for alerts | `tech@chain4travel.com` |
| `--api-url` | Public API URL | `https://columbus.camino.network` |
| `--internal-api-url` | Internal API URL | `https://internal.columbus.camino.network` |

### Optional Parameters

| Parameter | Description |
|-----------|-------------|
| `--skip-prometheus` | Skip Prometheus installation |
| `--skip-grafana` | Skip Grafana installation |
| `--skip-node-exporter` | Skip node_exporter installation |
| `--skip-pushgateway` | Skip pushgateway installation |
| `--skip-dashboards` | Skip dashboard installation |
| `--skip-alerts` | Skip alert installation |
| `--skip-push-daemons` | Skip push daemon installation |

## Directory Structure

```
grafana/
├── alerts/                    # Alert rule definitions
│   ├── health-alerts.yaml     # API, Magellan, Signavault health
│   ├── network-health.yaml    # Validator connectivity alerts
│   └── network-stability.yaml # Latency and uptime alerts
├── contact-points/            # Alert contact configurations
│   ├── default.yaml           # Default (Discord + Email)
│   ├── discord.yaml           # Discord webhook
│   └── email.yaml             # Email notifications
├── notification-policies/     # Notification routing
│   └── default.yaml
├── dashboards/                # Grafana dashboard JSONs
│   ├── c_chain.json
│   ├── database.json
│   ├── machine.json
│   ├── main.json
│   ├── network.json
│   ├── p_chain.json
│   ├── subnets.json
│   └── x_chain.json
├── install-monitoring.sh      # Main installer
├── push_health_status.sh      # Health status push daemon
├── push_validators_status.sh  # Validator status push daemon
└── export-grafana-alerts.sh   # Export alerts from existing Grafana
```

## What Gets Installed

1. **Prometheus** - Time series database for metrics
2. **Grafana** - Visualization and alerting platform
3. **node_exporter** - System metrics collector
4. **Pushgateway** - For pushing metrics from scripts
5. **Dashboards** - Pre-configured Camino monitoring dashboards
6. **Alerts** - Pre-configured alerting rules
7. **Push Daemons** - Services for collecting validator and health metrics

## Alert Categories

### Health Alerts
- Public API Node Health
- Internal API Node Health
- Magellan Health Status
- Signavault Health

### Network Health Alerts
- Connected Validator Nodes below 85% (critical)
- Connected Validator Nodes below 90% (high)
- Connected Validator Nodes below 95% (medium)

### Network Stability Alerts
- C Block Acceptance Latency above 2s
- Uptime below 90%
- Uptime below 99%

## Services Installed

After installation, the following systemd services will be running:

```bash
# Check service status
sudo systemctl status prometheus
sudo systemctl status grafana-server
sudo systemctl status node_exporter
sudo systemctl status pushgateway
sudo systemctl status push_validators_status
sudo systemctl status push_health_status
```

## Default Ports

| Service | Port | URL |
|---------|------|-----|
| Prometheus | 9090 | http://localhost:9090 |
| Grafana | 3000 | http://localhost:3000 |
| node_exporter | 9100 | http://localhost:9100/metrics |
| Pushgateway | 9091 | http://localhost:9091 |

## Grafana Default Login

- **Username:** admin
- **Password:** admin (you'll be prompted to change on first login)

## Exporting Alerts from Existing Installation

To export alerts from an existing Grafana installation:

```bash
# Set environment variables
export GRAFANA_URL="http://localhost:3000"
export GRAFANA_AUTH="admin:password"

# Run export script
./export-grafana-alerts.sh
```

Exported files will be saved in `grafana-export/` directory.
