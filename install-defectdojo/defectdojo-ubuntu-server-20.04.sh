#!/bin/bash
# Unattended DefectDojo Installation for Ubuntu Server 20.04 64-Bit
# Maintainer: github.contacts@protonmail.com
#
# This script installs DefectDojo server on Ubuntu Server 20.04 with all dependencies.
#
# INFORMATION
# Distribution       : Ubuntu 20.04 64-Bit
# DefectDojo Version  : sonarqube-9.9.8.100196
# PostgreSQL Version : latest version
#
# USAGE
#   wget -O ~/defectdojo-ubuntu-server-20.04.sh https://raw.githubusercontent.com/AntoineMeheut/ossf/refs/heads/main/install-defectdojo/defectdojo-ubuntu-server-20.04.sh
#   sudo bash ~/defectdojo-ubuntu-server-20.04.sh

##
# Local variables & functions
#
# Define log file path
logfile="/var/log/defectdojo-install.log"

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
run_command log "*==================================================================*" && echo -e "*==================================================================*"
run_command log " DefectDojo Installation has begun!" && echo -e " DefectDojo Installation has begun!"
run_command log "*==================================================================*" && echo -e "*==================================================================*"

##
# Changing the Hostname of server to sonar
#
run_command log "XXX..." && sudo XXX


# Final message
run_command log "*==================================================================*" && echo -e "*==================================================================*"
run_command log "DefectDojo successfully installed. Access it via http://your_server_ip:9000." && echo -e "DefectDojo successfully installed. Access it via http://your_server_ip:9000"
run_command log " " && echo -e " "
run_command log "Script written by Antoine Meheut, 2025." && echo -e "Script written by Antoine Meheut, 2025."
run_command log "https://github.com/AntoineMeheut" && echo -e "https://github.com/AntoineMeheut"
run_command log "*==================================================================*" && echo -e "*==================================================================*"