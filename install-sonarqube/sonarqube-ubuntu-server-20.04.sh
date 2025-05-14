#!/bin/bash
# Unattended Sonarqube Installation for Ubuntu Server 20.04 64-Bit
# Maintainer: github.contacts@protonmail.com
#
# This script installs Sonarqube server on Ubuntu Server 20.04 with all dependencies.
#
# INFORMATION
# Distribution      : Ubuntu 20.04 64-Bit
# GitLab Version    :
# Web Server        :
#
# USAGE
#   wget -O ~/sonarqube-ubuntu-server-20.04.sh https://raw.githubusercontent.com/AntoineMeheut/ossf/refs/heads/main/install-sonarqube/sonarqube-ubuntu-server-20.04.sh
#   sudo bash ~/sonarqube-server-12.04.sh

help_menu ()
{
  echo "Usage: $0 -d DOMAIN_VAR (-m|--mysql)|(-p|--postgresql)"
  echo "  -h,--help        Display this usage menu"
  echo "  -d,--domain-var  Set the domain variable for GitLab, e.g. gitlab.example.com"
  echo "  -p,--postgresql  Use PostgreSQL as the database (default)"
  echo "  -m,--mysql       Use MySQL as the database (not recommended)"
}

# Set the application user and home directory.
APP_USER=git
USER_ROOT=/home/$APP_USER
DATABASE_TYPE="PostgreSQL"

# Set the application root.
APP_ROOT=$USER_ROOT/gitlab

# Get the variables from the command line.
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      help_menu
      exit 0
      ;;
    -d|--domain-var)
      shift
      if test $# -gt 0; then
        DOMAIN_VAR=$1
      else 
        echo "No domain variable was specified."
        help_menu
        exit 1
      fi
      shift
      ;;
    -m|--mysql)
      shift
      DATABASE_TYPE="MySQL"
      ;;
    -p|--postgresql)
      shift
      DATABASE_TYPE="PostgreSQL"
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Check for domain variable.
if [ $DOMAIN_VAR ]; then
  echo -e "*==================================================================*\n"

  echo -e " GitLab Installation has begun!\n"
  
  echo -e "   Domain: $DOMAIN_VAR"
  echo -e "   GitLab URL: http://$DOMAIN_VAR/"
  echo -e "   Application Root: $APP_ROOT"
  echo -e "   Database Type: $DATABASE_TYPE\n"
  
  echo -e "*==================================================================*\n"
  sleep 3
else
  echo "Please specify DOMAIN_VAR using the -d flag."
  help_menu
  exit 1
fi

## 
# Installing Packages
#
echo -e "\n*== Installing new packages...\n"
sudo apt-get update -y 2>&1 >/dev/null
sudo apt-get upgrade -y
sudo apt-get install -y build-essential makepasswd zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl git-core openssh-server redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev python-docutils python-software-properties sendmail logrotate

#TODO for sonarqube installation
#!/bin/bash

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

# Changing the Hostname of server to sonar
run_command log "Setting the hostname to sonar..." && sudo hostnamectl set-hostname sonar

# Update and Upgrade the Ubuntu EC2
run_command log "Updating packages..." && sudo apt update -y
run_command log "Upgrading packages..." && sudo apt upgrade -y

# Configure ElasticSearch
log "Configuring ElasticSearch..."
run_command sudo sh -c 'echo "vm.max_map_count=262144" >> /etc/sysctl.conf'
run_command sudo sh -c 'echo "fs.file-max=65536" >> /etc/sysctl.conf'
run_command sudo sh -c 'echo "ulimit -n 65536" >> /etc/sysctl.conf'
run_command sudo sh -c 'echo "ulimit -u 4096" >> /etc/sysctl.conf'

log "First part of SonarQube installation done. Please go into your AWS console and reboot your instance before running part 2 of the installation"

#!/bin/bash

# Author: Chris Parbey

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

# Add PostgreSQL repository
log "Adding PostgreSQL repository..."
run_command sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Download and add PostgreSQL repository key
log "Downloading and adding PostgreSQL repository key..."
run_command wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - &>/dev/null

# Install PostgreSQL
log "Installing PostgreSQL..."
run_command sudo apt-get -y install postgresql postgresql-contrib

# Start and enable PostgreSQL
log "Starting and enabling PostgreSQL..."
run_command sudo systemctl enable --now postgresql

# Set password for Postgres user
log "Setting password for user Postgres..."
run_command sudo passwd postgres

# Setup database for Sonarqube
log "Setting up database for Sonarqube..."
run_command sudo -u postgres bash <<EOF
    createuser sonar
    psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'sonar';"
    psql -c "CREATE DATABASE sonarqube OWNER sonar;"
    psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"
EOF

# Install Java 17
log "Installing Java 17..."
run_command sudo apt-get install openjdk-17-jdk openjdk-17-jre -y

# Download and extract SonarQube
log "Downloading and extracting SonarQube..."
run_command sudo wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.4.87374.zip -P /opt/
run_command sudo apt-get -y install unzip
run_command sudo unzip -q /opt/sonarqube-9.9.4.87374.zip -d /opt/
run_command sudo rm /opt/sonarqube-9.9.4.87374.zip
run_command sudo mv /opt/sonarqube-9.9.4.87374/ /opt/sonarqube

# Create SonarQube user and set permissions
log "Creating user sonar and group sonar..."
run_command sudo groupadd sonar
run_command sudo useradd -c "sonar" -d /opt/sonarqube -g sonar sonar
run_command sudo chown sonar:sonar /opt/sonarqube -R

# Configure SonarQube properties
log "Configuring SonarQube properties..."
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

# Create the SonarQube service file
log "Creating SonarQube service file..."
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

# Start and enable the SonarQube service
log "Starting and enabling SonarQube service..."
run_command sudo systemctl enable --now sonar

# Final message
echo "SonarQube successfully installed. Access it via http://your_server_ip:9000."

# Double check application status
sudo -u $APP_USER -H bundle exec rake gitlab:check RAILS_ENV=production

echo -e "*==================================================================*\n"

echo -e " GitLab has been installed successfully!"
echo -e " Navigate to $DOMAIN_VAR in your browser to access the application.\n"

echo -e " Login with the default credentials:"
echo -e "   admin@local.host"
echo -e "   5iveL!fe\n"

if test $DATABASE_TYPE == 'MySQL'; then
  echo -e " Your MySQL username and passwords are located in the following file:"
  echo -e "   $APP_ROOT/config/mysql.yml\n"
else
  echo -e " Your PostgreSQL username and password is located in the following file:"
  echo -e "   $APP_ROOT/config/postgresql.yml\n"
fi

echo -e " Script written by Casey Scarborough, 2014."
echo -e " https://github.com/caseyscarborough\n"

echo -e "*==================================================================*"
