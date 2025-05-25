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
# Create the DefectDojo service file
#
run_command log "Creating DefectDojo service file..."
sudo tee /etc/systemd/system/dojo.service > /dev/null << EOF
[Unit]
Description=uWSGI instance to serve DefectDojo

[Service]
ExecStart=/bin/bash -c 'su - dojo -c "cd /opt/dojo/django-DefectDojo && source ../bin/activate && uwsgi --socket :8001 --wsgi-file wsgi.py --workers 7"'
Restart=always
RestartSec=3
#StandardOutput=syslog
#StandardError=syslog
SyslogIdentifier=dojo

[Install]
WantedBy=multi-user.target
EOF

##
# Create the Celery service file
#
run_command log "Creating Celery-worker service file..."
sudo tee /etc/systemd/system/celery-worker.service > /dev/null << EOF
[Unit]
Description=celery workers for DefectDojo
Requires=dojo.service
After=dojo.service

[Service]
ExecStart=/bin/bash -c 'su - dojo -c "cd /opt/dojo/django-DefectDojo && source ../bin/activate && celery -A dojo worker -l info --concurrency 3"'
Restart=always
RestartSec=3
#StandardOutput=syslog
#StandardError=syslog
SyslogIdentifier=celeryworker

[Install]
WantedBy=multi-user.target
EOF

##
# Create the Celery-beat service file
#
run_command log "Creating Celery-beat service file..."
sudo tee /etc/systemd/system/celery-beat.service > /dev/null << EOF
[Unit]
Description=celery beat for DefectDojo
Requires=dojo.service
After=dojo.service

[Service]
ExecStart=/bin/bash -c 'su - dojo -c "cd /opt/dojo/django-DefectDojo && source ../bin/activate && celery beat -A dojo -l info"'
Restart=always
RestartSec=3
#StandardOutput=syslog
#StandardError=syslog
SyslogIdentifier=celerybeat

[Install]
WantedBy=multi-user.target
EOF

##
# Start and enable the DefectDojo services
#
run_command log "Starting and enabling DefectDojo service..."
run_command sudo systemctl enable --now dojo.service
sleep 10
run_command log "Starting and enabling Celery-Worker service..."
run_command sudo systemctl enable --now celery-worker.service
sleep 10
run_command log "Starting and enabling Celery-Beat service..."
run_command sudo systemctl enable --now celery-beat.service
sleep 10

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