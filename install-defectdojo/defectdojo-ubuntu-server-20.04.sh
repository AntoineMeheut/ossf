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
# Modify DefectDojo docker-compose.yml file
#
run_command log "Modify DefectDojo docker-compose.yml file..."
sudo tee /home/dojo/django-DefectDojo/docker-compose.yml > /dev/null << EOF
# This docker-compose.yml file  is fully functional to evaluate DefectDojo
# in your local environment.
#
# Although Docker Compose is one of the supported installation methods to
# deploy a containerized DefectDojo in a production environment, the
# docker-compose.yml file is not intended for production use without first
# customizing it to your particular situation.
---
services:
  nginx:
    build:
      context: ./
      dockerfile: "Dockerfile.nginx-${DEFECT_DOJO_OS:-debian}"
    image: "defectdojo/defectdojo-nginx:${NGINX_VERSION:-latest}"
    depends_on:
      - uwsgi
    environment:
      NGINX_METRICS_ENABLED: "${NGINX_METRICS_ENABLED:-false}"
      DD_UWSGI_HOST: "${DD_UWSGI_HOST:-uwsgi}"
      DD_UWSGI_PORT: "${DD_UWSGI_PORT:-3031}"
    volumes:
      - defectdojo_media:/usr/share/nginx/html/media
    ports:
      - target: 8080
        published: ${DD_PORT:-8080}
        protocol: tcp
        mode: host
      - target: 8443
        published: ${DD_TLS_PORT:-8443}
        protocol: tcp
        mode: host
    restart: always
  uwsgi:
    build:
      context: ./
      dockerfile: "Dockerfile.django-${DEFECT_DOJO_OS:-debian}"
      target: django
    image: "defectdojo/defectdojo-django:${DJANGO_VERSION:-latest}"
    depends_on:
      - postgres
    entrypoint: ['/wait-for-it.sh', '${DD_DATABASE_HOST:-postgres}:${DD_DATABASE_PORT:-5432}', '-t', '30', '--', '/entrypoint-uwsgi.sh']
    environment:
      DD_DEBUG: 'False'
      DD_DJANGO_METRICS_ENABLED: "${DD_DJANGO_METRICS_ENABLED:-False}"
      DD_ALLOWED_HOSTS: "${DD_ALLOWED_HOSTS:-*}"
      DD_DATABASE_URL: ${DD_DATABASE_URL:-postgresql://defectdojo:defectdojo@postgres:5432/defectdojo}
      DD_CELERY_BROKER_URL: ${DD_CELERY_BROKER_URL:-redis://redis:6379/0}
      DD_SECRET_KEY: "${DD_SECRET_KEY:-hhZCp@D28z!n@NED*yB!ROMt+WzsY*iq}"
      DD_CREDENTIAL_AES_256_KEY: "${DD_CREDENTIAL_AES_256_KEY:-&91a*agLqesc*0DJ+2*bAbsUZfR*4nLw}"
      DD_DATABASE_READINESS_TIMEOUT: "${DD_DATABASE_READINESS_TIMEOUT:-30}"
    volumes:
        - type: bind
          source: ./docker/extra_settings
          target: /app/docker/extra_settings
        - "defectdojo_media:${DD_MEDIA_ROOT:-/app/media}"
    restart: always
  celerybeat:
    image: "defectdojo/defectdojo-django:${DJANGO_VERSION:-latest}"
    depends_on:
      - postgres
      - redis
    entrypoint: ['/wait-for-it.sh', '${DD_DATABASE_HOST:-postgres}:${DD_DATABASE_PORT:-5432}', '-t', '30', '--', '/entrypoint-celery-beat.sh']
    environment:
      DD_DATABASE_URL: ${DD_DATABASE_URL:-postgresql://defectdojo:defectdojo@postgres:5432/defectdojo}
      DD_CELERY_BROKER_URL: ${DD_CELERY_BROKER_URL:-redis://redis:6379/0}
      DD_SECRET_KEY: "${DD_SECRET_KEY:-hhZCp@D28z!n@NED*yB!ROMt+WzsY*iq}"
      DD_CREDENTIAL_AES_256_KEY: "${DD_CREDENTIAL_AES_256_KEY:-&91a*agLqesc*0DJ+2*bAbsUZfR*4nLw}"
      DD_DATABASE_READINESS_TIMEOUT: "${DD_DATABASE_READINESS_TIMEOUT:-30}"
    volumes:
        - type: bind
          source: ./docker/extra_settings
          target: /app/docker/extra_settings
    restart: always
  celeryworker:
    image: "defectdojo/defectdojo-django:${DJANGO_VERSION:-latest}"
    depends_on:
      - postgres
      - redis
    entrypoint: ['/wait-for-it.sh', '${DD_DATABASE_HOST:-postgres}:${DD_DATABASE_PORT:-5432}', '-t', '30', '--', '/entrypoint-celery-worker.sh']
    environment:
      DD_DATABASE_URL: ${DD_DATABASE_URL:-postgresql://defectdojo:defectdojo@postgres:5432/defectdojo}
      DD_CELERY_BROKER_URL: ${DD_CELERY_BROKER_URL:-redis://redis:6379/0}
      DD_SECRET_KEY: "${DD_SECRET_KEY:-hhZCp@D28z!n@NED*yB!ROMt+WzsY*iq}"
      DD_CREDENTIAL_AES_256_KEY: "${DD_CREDENTIAL_AES_256_KEY:-&91a*agLqesc*0DJ+2*bAbsUZfR*4nLw}"
      DD_DATABASE_READINESS_TIMEOUT: "${DD_DATABASE_READINESS_TIMEOUT:-30}"
    volumes:
        - type: bind
          source: ./docker/extra_settings
          target: /app/docker/extra_settings
        - "defectdojo_media:${DD_MEDIA_ROOT:-/app/media}"
    restart: always
  initializer:
    image: "defectdojo/defectdojo-django:${DJANGO_VERSION:-latest}"
    depends_on:
      - postgres
    entrypoint: ['/wait-for-it.sh', '${DD_DATABASE_HOST:-postgres}:${DD_DATABASE_PORT:-5432}', '--', '/entrypoint-initializer.sh']
    environment:
      DD_DATABASE_URL: ${DD_DATABASE_URL:-postgresql://defectdojo:defectdojo@postgres:5432/defectdojo}
      DD_ADMIN_USER: "${DD_ADMIN_USER:-admin}"
      DD_ADMIN_MAIL: "${DD_ADMIN_USER:-admin@defectdojo.local}"
      DD_ADMIN_FIRST_NAME: "${DD_ADMIN_FIRST_NAME:-Admin}"
      DD_ADMIN_LAST_NAME: "${DD_ADMIN_LAST_NAME:-User}"
      DD_INITIALIZE: "${DD_INITIALIZE:-true}"
      DD_SECRET_KEY: "${DD_SECRET_KEY:-hhZCp@D28z!n@NED*yB!ROMt+WzsY*iq}"
      DD_CREDENTIAL_AES_256_KEY: "${DD_CREDENTIAL_AES_256_KEY:-&91a*agLqesc*0DJ+2*bAbsUZfR*4nLw}"
      DD_DATABASE_READINESS_TIMEOUT: "${DD_DATABASE_READINESS_TIMEOUT:-30}"
    volumes:
        - type: bind
          source: ./docker/extra_settings
          target: /app/docker/extra_settings
  postgres:
    image: postgres:17.4-alpine@sha256:7062a2109c4b51f3c792c7ea01e83ed12ef9a980886e3b3d380a7d2e5f6ce3f5
    environment:
      POSTGRES_DB: ${DD_DATABASE_NAME:-defectdojo}
      POSTGRES_USER: ${DD_DATABASE_USER:-defectdojo}
      POSTGRES_PASSWORD: ${DD_DATABASE_PASSWORD:-defectdojo}
    volumes:
      - defectdojo_postgres:/var/lib/postgresql/data
    restart: always
  redis:
    # Pinning to this version due to licensing constraints
    image: redis:7.2.8-alpine@sha256:c88ea2979a49ca497bbf7d39241b237f86c98e58cb2f6b1bc2dd167621f819bb
    volumes:
      - defectdojo_redis:/data
    restart: always
volumes:
  defectdojo_postgres: {}
  defectdojo_media: {}
  defectdojo_redis: {}

EOF

##
# Start and enable the DefectDojo services
#
run_command log "Starting and enabling DefectDojo service..."
run_command docker compose up -d
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