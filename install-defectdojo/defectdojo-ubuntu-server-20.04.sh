#!/bin/bash
# Unattended DefectDojo Installation for Ubuntu Server 20.04 64-Bit
# Maintainer: github.contacts@protonmail.com
#
# This script installs DefectDojo server on Ubuntu Server 20.04 with all dependencies.
#
# INFORMATIONS
# Distribution        : Ubuntu 20.04 64-Bit
# DefectDojo Version  : sonarqube-9.9.8.100196
# PostgreSQL Version  : latest version
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
run_command log "*==================================================================*"
run_command log " DefectDojo Installation has begun!"
run_command log "*==================================================================*"

##
# Clone the DefectDojo project
#
run_command log "Clone the DefectDojo project..." && git clone https://github.com/DefectDojo/django-DefectDojo
run_command log "Go to django-DefectDojo directory..." && cd django-DefectDojo

##
# Check if your installed toolkit is compatible
#
run_command log "Start docker compose..." && ./docker/docker-compose-check.sh

##
# Building Docker images
#
run_command log "Build docker image..." && docker compose build

##
# Run the application (for other profiles besides postgres-redis see
# https://github.com/DefectDojo/django-DefectDojo/blob/dev/readme-docs/DOCKER.md)
#
run_command log "Start the application..." && sudo docker compose up -d
sleep 60

##
# Get vm ip
#
run_command log "Get vm ip..."
VM_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
ADMIN_LOGON=$(sudo docker logs django-defectdojo-initializer-1 | grep "Admin user:")
ADMIN_PASS=$(sudo docker logs django-defectdojo-initializer-1 | grep "Admin password:")

##
# Final message
#
run_command log "*==================================================================*"
run_command log "DefectDojo has been installed successfully!"
run_command log "Access it via http://$VM_IP:8080/login"
run_command log "$ADMIN_LOGON"
run_command log "$ADMIN_PASS"
run_command log " "
run_command log "Script written by Antoine Meheut, 2025."
run_command log "https://github.com/AntoineMeheut"
run_command log "*==================================================================*"