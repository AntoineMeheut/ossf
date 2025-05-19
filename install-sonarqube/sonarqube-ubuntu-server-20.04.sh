#!/bin/bash
# Unattended Sonarqube Installation for Ubuntu Server 20.04 64-Bit
# Maintainer: github.contacts@protonmail.com
#
# This script installs Sonarqube server on Ubuntu Server 20.04 with all dependencies.
#
# INFORMATION
# Distribution       : Ubuntu 20.04 64-Bit
# Sonarqube Version  : sonarqube-9.9.8.100196
# PostgreSQL Version : latest version
#
# USAGE
#   wget -O ~/sonarqube-ubuntu-server-20.04.sh https://raw.githubusercontent.com/AntoineMeheut/ossf/refs/heads/main/install-sonarqube/sonarqube-ubuntu-server-20.04.sh
#   sudo bash ~/sonarqube-ubuntu-server-20.04.sh

##
# Local variables & functions
#
# Define log file path
logfile="/var/log/sonar-install.log"

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
run_command log " Sonarqube Installation has begun!"
run_command log "*==================================================================*"

##
# Changing the Hostname of server to sonar
#
run_command log "Setting the hostname to sonar..." && sudo hostnamectl set-hostname sonar

##
# Update and Upgrade Ubuntu
#
run_command log "Updating packages..." && sudo apt update -y
run_command log "Upgrading packages..." && sudo apt upgrade -y

##
# Install Java 17
#
run_command log "Installing Java 17..."
run_command sudo apt-get install openjdk-17-jdk openjdk-17-jre -y

##
# Configure ElasticSearch
#
run_command log "Configuring ElasticSearch..."
run_command sudo sh -c 'echo "vm.max_map_count=262144" >> /etc/sysctl.conf'
run_command sudo sh -c 'echo "fs.file-max=65536" >> /etc/sysctl.conf'
run_command sudo sh -c 'echo "ulimit -n 65536" >> /etc/sysctl.conf'
run_command sudo sh -c 'echo "ulimit -u 4096" >> /etc/sysctl.conf'

##
# Add PostgreSQL repository
#
run_command log "Adding PostgreSQL repository..."
run_command sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

##
# Download and add PostgreSQL repository key
#
run_command log "Downloading and adding PostgreSQL repository key..."
run_command wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - &>/dev/null

##
# Install PostgreSQL
#
run_command log "Installing PostgreSQL..."
run_command sudo apt-get -y install postgresql postgresql-contrib

##
# Start and enable PostgreSQL
#
run_command log "Starting and enabling PostgreSQL..."
run_command sudo systemctl enable --now postgresql

##
# Set password for Postgres user
#
run_command log "Setting password for user Postgres..."
run_command sudo passwd postgres

##
# Setup database for Sonarqube
#
run_command log "Setting up database for Sonarqube..."
run_command sudo -u postgres bash <<EOF
    createuser sonar
    psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'sonar';"
    psql -c "CREATE DATABASE sonarqube OWNER sonar;"
    psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"
EOF

##
# Download and extract SonarQube
#
run_command log "Installing Sonarqube..."
run_command sudo wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.8.100196.zip -P /opt/
run_command sudo apt-get -y install unzip
run_command sudo unzip -q /opt/sonarqube-9.9.8.100196.zip -d /opt/
run_command sudo rm /opt/sonarqube-9.9.8.100196.zip
run_command sudo mv /opt/sonarqube-9.9.8.100196/ /opt/sonarqube

##
# Set permissions
#
run_command log "Set permissions..."
log "Set permissions..."
run_command sudo chown sonar:sonar /opt/sonarqube -R

##
# Configure SonarQube properties
#
run_command log "Configuring SonarQube properties..."
sonar_properties="/opt/sonarqube/conf/sonar.properties"
sonar_user_ln="26"
sonar_pass_ln="27"
postgres_url_ln="28"
sonar_username="sonar.jdbc.username=sonar" # User can change to desired username
sonar_passwd="sonar.jdbc.password=sonar" # User can change to desired password
postgres_url="sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube" # User can replace sonarqube with their own DB name

run_command sudo sed -i "${sonar_user_ln}s/.*/${sonar_username}/" "${sonar_properties}"
run_command sudo sed -i "${sonar_pass_ln}s/.*/${sonar_passwd}/" "${sonar_properties}"
run_command sudo sed -i "${postgres_url_ln}i${postgres_url}" "${sonar_properties}"

##
# Create the SonarQube service file
#
run_command log "Creating SonarQube service file..."
sudo tee /etc/systemd/system/sonar.service > /dev/null << EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

##
# Start and enable the SonarQube service
#
run_command log "Starting and enabling SonarQube service..."
run_command sudo systemctl enable --now sonar

##
# Final message
#
run_command log "*==================================================================*"
run_command log "SonarQube successfully installed. Access it via http://your_server_ip:9000."
run_command log " "
run_command log "Script written by Antoine Meheut, 2025."
run_command log "https://github.com/AntoineMeheut"
run_command log "*==================================================================*"