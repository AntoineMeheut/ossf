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

##
# Obtain admin credentials. The initializer can take up to 3 minutes to run.
# Use docker compose logs -f initializer to track its progress.
run_command log "Show admin credentials..." && docker compose logs initializer | grep "Admin password:"

##
# Final message
#
run_command log "*==================================================================*"
run_command log "DefectDojo successfully installed. Access it via http://your_server_ip:8080."
run_command log "Your admin password is:"
run_command docker compose logs initializer | grep "Admin password:"
run_command log " "
run_command log "Script written by Antoine Meheut, 2025."
run_command log "https://github.com/AntoineMeheut"
run_command log "*==================================================================*"