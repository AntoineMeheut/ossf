#!/bin/bash
# Unattended Nexus Installation for Ubuntu Server 20.04 64-Bit
# Maintainer: github.contacts@protonmail.com
#
# This script installs Nexus server on Ubuntu Server 20.04 with all dependencies.
#
# INFORMATIONS
# Distribution        : Ubuntu 20.04 64-Bit
# Nexus Version       : nexus-3.80.0-06-linux-aarch_64
#
# USAGE
#   wget -O ~/nexus-ubuntu-server-20.04.sh https://raw.githubusercontent.com/AntoineMeheut/ossf/refs/heads/main/install-nexus/nexus-ubuntu-server-20.04.sh
#   sudo bash ~/nexus-ubuntu-server-20.04.sh

##
# Local variables & functions
#
##
# Latest Nexus Downlad url & log file path
#
download_url="https://download.sonatype.com/nexus/3/nexus-3.80.0-06-linux-aarch_64.tar.gz"
downloaded_file="nexus-3.80.0-06-linux-aarch_64.tar.gz"
nexus_version="nexus-3.80.0-06"
sonatype_work="sonatype-work"
logfile="/var/log/nexus-install.log"

# Function to log to both file and terminal with timestamp
log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp $1" | sudo tee -a "$logfile"
}

# Function to log and exit on error
log_and_exit() {
    log "$1"
    exit 1
}

# Function to run command and log errors
run_command() {
    "$@" || log_and_exit "Error: Failed to execute command: $*"
}

##
# Start of installation
#
run_command log "*==================================================================*"
run_command log " Nexus Installation has begun!"
run_command log "*==================================================================*"

##
# Ubuntu update & upgrade
#
run_command log "Ubuntu update & upgrade..."
run_command sudo apt-get update -y 2>&1 >/dev/null
run_command sudo apt-get upgrade -y

##
# Install Ubuntu net-tools
#
run_command log "Install Ubuntu net-tools..." && sudo apt install net-tools -y

##
# Install OpenJDK 8
#
run_command log "Install OpenJDK 8..."
run_command sudo apt install -y openjdk-8-jre-headless

##
# Download Nexus
#
run_command log "Download Nexus..."
run_command sudo wget "$download_url"

##
# Extract and move the downloaded file
#
run_command log "Extract and move the downloaded file..."
run_command sudo tar -zxvf "$downloaded_file"
run_command sudo mv "$nexus_version" /opt
run_command sudo mv "$sonatype_work" /opt
run_command sudo rm -rf "$downloaded_file"

##
# Set ownership for Nexus directories (checking if nexus_version is set)
#
run_command log "Set ownership for Nexus directories (checking if nexus_version is set)..."
if [ -n "$nexus_version" ]; then
  run_command sudo chown -R nexus:nexus /opt/"$nexus_version"
  run_command sudo chown -R nexus:nexus /opt/sonatype-work
else
  run_command log "Set ownership for Nexus directories (checking if nexus_version is set)."
  exit 1
fi

##
# Create the Nexus service file
#
run_command log "Creating Nexus service file..."
sudo tee /etc/systemd/system/nexus.service > /dev/null << EOF
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/"$nexus_version"/bin/nexus start
ExecStop=/opt/"$nexus_version"/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

##
# Start and enable the Nexus service
#
run_command log "Starting and enabling Nexus service..."
run_command sudo systemctl enable --now nexus
sleep 60

##
# Get vm ip
#
run_command log "Get vm ip..."
VM_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
ADMIN_LOGON="admin"
ADMIN_PASS=$(sudo cat /opt/sonatype-work/nexus3/admin.password)

##
# Final message
#
run_command log "*==================================================================*"
run_command log "Nexus has been installed successfully!"
run_command log "Access it via http://$VM_IP:8081"
run_command log "$ADMIN_LOGON"
run_command log "$ADMIN_PASS"
run_command log " "
run_command log "Script written by Antoine Meheut, 2025."
run_command log "https://github.com/AntoineMeheut"
run_command log "*==================================================================*"