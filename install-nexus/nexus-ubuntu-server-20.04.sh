#!/bin/bash
# Unattended Nexus Installation for Ubuntu Server 20.04 64-Bit
# Maintainer: github.contacts@protonmail.com
#
# This script installs Nexus server on Ubuntu Server 20.04 with all dependencies.
#
# INFORMATIONS
# Distribution        : Ubuntu 20.04 64-Bit
# Nexus Version       : latest
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
download_url="https://download.sonatype.com/nexus/3/latest-unix.tar.gz"
downloaded_file="latest-unix.tar.gz"
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
# Install OpenJDK 8
#
run_command log "Install OpenJDK 8..."
run_command sudo apt install -y openjdk-8-jre-headless

##
# Navigate to the /opt directory
#
run_command log "Navigate to the /opt directory..."
run_command cd /opt

##
# Download Nexus
#
run_command log "Download Nexus..."
run_command sudo wget "$download_url"

##
# Extract Nexus version from the downloaded file name
#
run_command log "Extract Nexus version from the downloaded file name..."
run_command nexus_version=$(tar tzf "$downloaded_file" | grep -oP 'nexus-3\.\d+\.\d+-\d+' | head -n 1)
run_command sudo tar -zxvf "$downloaded_file"

##
# Create a Nexus user (modify as needed for password input)
#
run_command log "Create a Nexus user (modify as needed for password input)..."
run_command sudo useradd -m -s /bin/bash -U nexus

##
# Change password for the Nexus user password: nexus123
#
run_command log "Change password for the Nexus user password: nexus123..."
run_command echo "nexus:nexus123" | sudo chpasswd

##
# Set ownership for Nexus directories (checking if nexus_version is set)
#
run_command log "Set ownership for Nexus directories (checking if nexus_version is set)..."
if [ -n "$nexus_version" ]; then
  run_command sudo chown -R nexus:nexus "$nexus_version"
  run_command sudo chown -R nexus:nexus sonatype-work
else
  run_command log "Failed to determine Nexus version. Check the script and try again."
  exit 1
fi

##
# Edit Nexus runtime configuration (checking if nexus_version is set)
#
run_command log "Edit Nexus runtime configuration (checking if nexus_version is set)..."
if [ -n "$nexus_version" ]; then
  run_command sudo sed -i 's/^run_as_user=.*/run_as_user="nexus"/' "/opt/$nexus_version/bin/nexus.rc"
else
  run_command log "Failed to determine Nexus version. Check the script and try again."
  exit 1
fi

##
# Switch to the Nexus user and start Nexus
#
run_command log "Switch to the Nexus user and start Nexus..."
run_command sudo su - nexus <<EOF
/opt/$nexus_version/bin/nexus start
EOF

##
# Wait for 60 seconds to allow Nexus to initialize
#
run_command log "Wait for 60 seconds to allow Nexus to initialize..."
run_command sleep 60

##
# Check Nexus process status
#
run_command log "Check Nexus process status..."
run_command ps aux | grep nexus

##
# Check Nexus port status
#
run_command log "Check Nexus port status..."
run_command netstat -lnpt

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
run_command log "Access it via http://$VM_IP:8080"
run_command log "$ADMIN_LOGON"
run_command log "$ADMIN_PASS"
run_command log " "
run_command cat /opt/sonatype-work/nexus3/admin.password
run_command log "\n"
run_command log "Script written by Antoine Meheut, 2025."
run_command log "https://github.com/AntoineMeheut"
run_command log "*==================================================================*"