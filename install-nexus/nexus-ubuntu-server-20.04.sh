#!/bin/bash
# Unattended Nexus Installation for Ubuntu Server 20.04 64-Bit
# Maintainer: github.contacts@protonmail.com
#
# This script installs Nexus server on Ubuntu Server 20.04 with all dependencies.
#
# INFORMATIONS
# Distribution        : Ubuntu 20.04 64-Bit
# Nexus Version       : TODO
# PostgreSQL Version  : latest version
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
# Install net-tools
#
run_command sudo apt install -y net-tools

# Navigate to the /opt directory
run_command cd /opt

# Download Nexus
sudo wget "$download_url"

# Extract Nexus version from the downloaded file name
run_command nexus_version=$(tar tzf "$downloaded_file" | grep -oP 'nexus-3\.\d+\.\d+-\d+' | head -n 1)

# Extract Nexus
run_command sudo tar -zxvf "$downloaded_file"

# Create a Nexus user (modify as needed for password input)
run_command sudo useradd -m -s /bin/bash -U nexus

# Set password for the Nexus user password: nexus123
#Change with your own password
echo "nexus:nexus123" | sudo chpasswd

# Set ownership for Nexus directories (checking if nexus_version is set)
if [ -n "$nexus_version" ]; then
  sudo chown -R nexus:nexus "$nexus_version"
  sudo chown -R nexus:nexus sonatype-work
else
  echo "Failed to determine Nexus version. Check the script and try again."
  exit 1
fi

# Edit Nexus runtime configuration (checking if nexus_version is set)
if [ -n "$nexus_version" ]; then
  sudo sed -i 's/^run_as_user=.*/run_as_user="nexus"/' "/opt/$nexus_version/bin/nexus.rc"
else
  echo "Failed to determine Nexus version. Check the script and try again."
  exit 1
fi

# Switch to the Nexus user and start Nexus
sudo su - nexus <<EOF
/opt/$nexus_version/bin/nexus start
EOF

# Wait for 60 seconds to allow Nexus to initialize
echo "Waiting for Nexus to initialize..."
sleep 60

# Check Nexus process status
ps aux | grep nexus

# Check Nexus port status
netstat -lnpt

# Print admin password
echo -e "=========== Admin Password ===========\n"
cat /opt/sonatype-work/nexus3/admin.password
echo -e "\n"
echo -e "=========== Admin Password ==========="


##
# Final message
#
run_command log "*==================================================================*"
run_command log "Nexus successfully installed. Access it via http://your_server_ip:8080."
run_command log "Your admin password is:"
run_command docker compose logs initializer | grep "Admin password:"
run_command log " "
run_command log "Script written by Antoine Meheut, 2025."
run_command log "https://github.com/AntoineMeheut"
run_command log "*==================================================================*"