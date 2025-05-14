#!/bin/bash
# Unattended GitLab Installation for Ubuntu Server 20.04 64-Bit
# Maintainer: github.contacts@protonmail.com
# GitLab Version: latest version
#
# This script installs GitLab server on Ubuntu Server 20.04 with all dependencies.
#
# INFORMATION
# Distribution      : Ubuntu 20.04 64-Bit
# GitLab Version    : latest version
# Web Server        : postfix
# Init System       : systemd
#
# USAGE
#   wget -O ~/gitlab-ubuntu-server-20.04.sh https://raw.githubusercontent.com/AntoineMeheut/ossf/refs/heads/main/install-gitlab-ce/gitlab-ubuntu-server-20.04.sh
#   sudo bash ~/gitlab-ubuntu-server-20.04.sh -d gitlab.ame.tech

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
        echo "No domain variable was specified."
        help_menu
        exit 1
      fi
      shift
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
  
  echo -e "*==================================================================*\n"
  sleep 3
else
  echo "Please specify DOMAIN_VAR using the -d flag."
  help_menu
  exit 1
fi

##
# Ubuntu update & upgrade
#
echo -e "\n*== Ubuntu update & upgrade...\n"
sudo apt-get update -y 2>&1 >/dev/null
sudo apt-get upgrade -y

##
# Installing dependencies
#
echo -e "\n*== Installing dependencies...\n"
sudo apt-get install -y curl openssh-server ca-certificates tzdata perl postfix

##
# Install GitLab
#
echo -e "\n*== Installing GitLab...\n"
cd $USER_TMP
sudo curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
sudo apt-get install gitlab-ce
sudo apt-mark hold gitlab-ce

##
# Modify gitlab url
#
echo -e "\n*== Modify gitlab url...\n"
# sudo nano /etc/gitlab/gitlab.rb
sudo sed -i "s/gitlab.example.com/$DOMAIN_VAR/" /etc/gitlab/gitlab.rb

##
# Reconfigure Gitlab
#
echo -e "\n*== Reconfigure Gitlab...\n"
sudo gitlab-ctl reconfigure

##
# Install Gitlab Runner
#
echo -e "\n*== Install Gitlab Runner...\n"
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install gitlab-runner

# Check application status
sudo systemctl status gitlab-runsvdir.service

# Final exit
echo -e "*==================================================================*\n"

echo -e " GitLab has been installed successfully!"
echo -e " Navigate to $DOMAIN_VAR in your browser to access the application.\n"

echo -e " Script written by Antoine Meheut, 2025."
echo -e " https://github.com/AntoineMeheut\n"

echo -e "*==================================================================*"
