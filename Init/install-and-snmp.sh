#!/bin/bash

# Function to check if a package is installed, and install it if not
install_if_not_installed() {
    if ! dpkg -l | grep -q "^ii  $1"; then
        sudo apt-get install -y $1
    else
        echo "$1 is already installed"
    fi
}

# Step 1: Install base packages
echo "Installing base packages..."
base_packages=("procps" "util-linux" "sysstat" "iproute2" "numactl")
for package in "${base_packages[@]}"; do
    install_if_not_installed $package
done

# Step 2: Add networking tools
echo "Installing networking tools..."
networking_tools=("tcpdump" "nicstat" "ethtool")
for tool in "${networking_tools[@]}"; do
    install_if_not_installed $tool
done

# Step 3: Profiling and tracing tools
echo "Installing profiling and tracing tools..."
profiling_tools=("linux-tools-common" "linux-tools-$(uname -r)" "bpfcc-tools" "bpftrace" "trace-cmd")
for tool in "${profiling_tools[@]}"; do
    install_if_not_installed $tool
done

# Install rmlint
echo "Installing rmlint..."
install_if_not_installed "rmlint"

echo "All packages have been installed successfully."
# ----------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Update the package list
echo "Updating package list..."
apt update

# Install SNMP and SNMPD
echo "Installing SNMP and SNMPD..."
apt install -y snmp snmpd

# Backup the original snmpd.conf file
echo "Backing up the original snmpd.conf file..."
cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bak

# Configure SNMPD
echo "Configuring SNMPD..."
cat > /etc/snmp/snmpd.conf <<EOL
# This file controls the configuration of the snmpd daemon

# sec.name source community
com2sec readonly  default         public

# group.name sec.model sec.name
group MyROGroup v1           readonly
group MyROGroup v2c           readonly

# This line should be uncommented for SNMPv3, leaving it commented for SNMPv2c
# group MyROGroup usm           readonly

# view.name type     include/exclude     subtree
view all    included  .1                               80

# access.name  context model level prefix read   write  notif
access MyROGroup ""      any    noauth    exact  all    none   none

sysLocation    Local
sysContact     Admin <admin@example.com>
EOL

# Restart the SNMPD service
echo "Restarting SNMPD service..."
systemctl restart snmpd

# Enable the SNMPD service to start on boot
echo "Enabling SNMPD service to start on boot..."
systemctl enable snmpd

# Open the SNMP port (161) in the firewall
echo "Opening port 161 for SNMP..."
ufw allow 161/udp
ufw allow ssh
ufw enable

echo "SNMP installation and configuration complete."