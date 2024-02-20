#!/bin/bash

# Initialize the flag indicating whether to skip the OS check
skip_os_check=false
install_grafana=false

# Process command-line options
while getopts "fg" opt; do
  case $opt in
    f)
      skip_os_check=true
      ;;
    g)
      install_grafana=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Check the OS version if the -f flag is not set
if ! $skip_os_check; then
  if grep -q 'Ubuntu 22.04' /etc/os-release; then
      echo "Running on Ubuntu 22.04, proceeding..."
  else
      echo "This script is intended for Ubuntu 22.04. Exiting."
      exit 1
  fi
else
  echo "Skipping OS check as per -f flag."
fi

# Perform system update and upgrade
echo "Updating package lists..."
sudo apt update

echo "Upgrading packages..."
sudo apt upgrade -y

# Adding Grafana apt repositories
# Copied from https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/

echo "Adding Grafana apt repositories"
# Installing dependencies
sudo apt-get install -y apt-transport-https software-properties-common wget

# Adding Grafana keyring
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

# Adding Grafana repository
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

# Updating package list and installing Prometheus
sudo apt update
echo "Installing Prometheus"
sudo apt install -y prometheus
# Installing Grafana locally if necessary
if $install_grafana; then
  echo "Installing Grafana"
  sudo apt install -y grafana
fi

# Installing Tailscale
echo "Installing Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
sleep 1

# Fetching Tailscale interface IP address
tailscale_ip=$(ip addr show tailscale0 | grep 'inet\b' | awk '{print $2}' | cut -d/ -f1)
echo "This system's Tailscale IP address is $tailscale_ip"

if $install_grafana; then
  prometheus_ip=127.0.0.1
  grafana_ip=$tailscale_ip
else
  prometheus_ip=$tailscale_ip
fi

node_exporter_ip=127.0.0.1

echo "Configuring Prometheus and node-exporter's listen addresses"
# Binding Prometheus to the tailscale interface
# Set Prometheus IP address
# Check if 'ARGS' line exists, and modify it or append it
if grep -q '^ARGS=' /etc/default/prometheus; then
  sudo sed -i "/^ARGS=/c\ARGS=\"--web.listen-address=$prometheus_ip:9090\"" /etc/default/prometheus
else
  echo "ARGS=\"--web.listen-address=$prometheus_ip:9090\"" | sudo tee -a /etc/default/prometheus
fi



# Set node-exporter IP address
# Check if 'ARGS' line exists, and modify it or append it
if grep -q '^ARGS=' /etc/default/prometheus-node-exporter; then
  sudo sed -i "/^ARGS=/c\ARGS=\"--web.listen-address=$node_exporter_ip:9100\"" /etc/default/prometheus-node-exporter
else
  echo "ARGS=\"--web.listen-address=$node_exporter_ip:9100\"" | sudo tee -a /etc/default/prometheus-node-exporter
fi

# Configuring Grafana's IP address if enabled
if $install_grafana; then
  echo "Setting Grafana's listen IP address to $grafana_ip"
  sudo sed -i "/;http_addr/c\http_addr = $grafana_ip" /etc/grafana/grafana.ini
fi

# Enabling and starting services
echo "Enabling and starting prometheus-node-exporter.service"
sudo systemctl enable prometheus-node-exporter.service
sudo systemctl start prometheus-node-exporter.service

echo "Enabling and starting prometheus.service"
sudo systemctl enable prometheus.service
sudo systemctl start prometheus.service

if $install_grafana; then
  echo "Enabling and starting grafana-server.service"
  sudo systemctl enable grafana-server.service
  sudo systemctl start grafana-server.service
fi

sleep 1
# Restarting the services ???

sudo systemctl restart prometheus.service
sudo systemctl restart prometheus-node-exporter.service
if $install_grafana; then
  sudo systemctl restart grafana-server.service
fi