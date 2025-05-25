#!/bin/bash
# Unattended GitLab Installation for Ubuntu Server 20.04 64-Bit
# Maintainer: github.contacts@protonmail.com
#
# This script installs GitLab server on Ubuntu Server 20.04 with all dependencies.
#
# INFORMATIONS
# Distribution      : Ubuntu 20.04 64-Bit
# GitLab Version    : latest version
# PostgreSQL        : latest version
# Web Server        : postfix
#
# USAGE
#   wget -O ~/gitlab-ubuntu-server-20.04.sh https://raw.githubusercontent.com/AntoineMeheut/ossf/refs/heads/main/install-gitlab-ce/gitlab-ubuntu-server-20.04.sh
#   sudo bash ~/gitlab-ubuntu-server-20.04.sh -d gitlab.ame.tech

##
# Local variables & functions
#
# Define log file path
logfile="/var/log/gitlab-ce-install.log"

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

help_menu ()
{
  echo "Usage: $0 -d DOMAIN_VAR "
  echo "  -h,--help        Display this usage menu"
  echo "  -d,--domain-var  Set the domain variable for GitLab, e.g. gitlab.example.com"
}

# Set the application user and home directory.
APP_USER=git
USER_TMP=/tmp

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
        run_command log "No domain variable was specified."
        help_menu
        exit 1
      fi
      shift
      ;;
    *)
      run_command log "Unknown argument: $1"
      exit 1
      ;;
  esac
done

##
# Start of installation
#
# Check for domain variable.
if [ $DOMAIN_VAR ]; then
  run_command log "*==================================================================*"
  run_command log " Gitlab-ce Installation has begun!"
  run_command log "   Domain: $DOMAIN_VAR"
  run_command log "   GitLab URL: http://$DOMAIN_VAR/"
  run_command log "*==================================================================*"
  sleep 3
else
  run_command log "Please specify DOMAIN_VAR using the -d flag."
  help_menu
  exit 1
fi

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
# Installing dependencies
#
run_command log "Installing dependencies..."
run_command sudo apt-get install -y curl openssh-server ca-certificates tzdata perl postfix

##
# Install GitLab
#
run_command log "Installing GitLab..."
run_command cd $USER_TMP
run_command sudo curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
run_command sudo apt-get install gitlab-ce
run_command sudo apt-mark hold gitlab-ce

##
# Modify gitlab url
#
run_command log "Modify gitlab url..."
run_command sudo sed -i "s/gitlab.example.com/$DOMAIN_VAR/" /etc/gitlab/gitlab.rb

##
# Reconfigure Gitlab
#
run_command log "Reconfigure Gitlab..."
run_command sudo gitlab-ctl reconfigure

##
# Install Gitlab Runner
#
run_command log "Install Gitlab Runner..."
run_command curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
run_command sudo apt install gitlab-runner

##
# Get vm ip
#
run_command log "Get vm ip..."
VM_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
ADMIN_LOGON="root"
ADMIN_PASS=$(sudo cat /etc/gitlab/initial_root_password | grep "Password: ")

##
# Final exit
#
run_command log "*==================================================================*"
run_command log "GitLab has been installed successfully!"
run_command log "Your domain name is $DOMAIN_VAR, use it directly or,"
run_command log "Access it via http://$VM_IP"
run_command log "$ADMIN_LOGON"
run_command log "$ADMIN_PASS"
run_command log " "
run_command log "Script written by Antoine Meheut, 2025."
run_command log "https://github.com/AntoineMeheut"
run_command log "*==================================================================*"
