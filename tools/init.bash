#!/usr/bin/env bash
set -Eeuo pipefail

# -------------------------------------
# YouTrack setup script
# -------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
VOL_DIR="${SCRIPT_DIR}/../vol"

CURRENT_YOUTRACK_VERSION="2025.2.100871"

load_existing_env() {
    set -o allexport
    source "$ENV_FILE"
    set +o allexport
}

prompt_for_configuration() {
    echo "Please enter configuration values (press Enter to keep current/default value):"
    echo ""

    echo "Base settings:"
    YOUTRACK_VERSION=${CURRENT_YOUTRACK_VERSION}

    read -p "YOUTRACK_APP_HOSTNAME [${YOUTRACK_APP_HOSTNAME:-https://youtrack.example.com}]: " input
    YOUTRACK_APP_HOSTNAME=${input:-${YOUTRACK_APP_HOSTNAME:-https://youtrack.example.com}}
}

confirm_and_save_configuration() {
    CONFIG_LINES=(
        "# YouTrack"
        "YOUTRACK_VERSION=${YOUTRACK_VERSION}"
        "YOUTRACK_APP_HOSTNAME=${YOUTRACK_APP_HOSTNAME}"
        ""
    )

    echo ""
    echo "The following environment configuration will be saved:"
    echo "-----------------------------------------------------"
    for line in "${CONFIG_LINES[@]}"; do
        echo "$line"
    done
    echo "-----------------------------------------------------"
    echo ""

    read -p "Proceed with this configuration? (y/n): " CONFIRM
    echo ""
    if [[ "$CONFIRM" != "y" ]]; then
        echo "Configuration aborted by user."
        echo ""
        exit 1
    fi

    printf "%s\n" "${CONFIG_LINES[@]}" >"$ENV_FILE"
    echo ".env file saved to $ENV_FILE"
    echo ""
}

setup_containers() {
    echo "Stopping all containers and removing volumes..."
    docker compose down -v || true

    if [ -d "$VOL_DIR" ]; then
        echo "The 'vol' directory exists:"
        echo " - Type 'y' to clear it completely (new installation)."
        echo " - Type 'n' (or press Enter) to keep data."
        read -p "Clear it now? (y/N): " CONFIRM
        echo ""
        if [[ "$CONFIRM" == "y" ]]; then
            echo "Clearing 'vol' directory..."
            rm -rf "${VOL_DIR:?}"/*
        fi
    fi

    echo "Creating YouTrack directories..."
    mkdir -p "${VOL_DIR}/youtrack-app/opt/youtrack/data"     && chown 13001:13001 "${VOL_DIR}/youtrack-app/opt/youtrack/data"
    mkdir -p "${VOL_DIR}/youtrack-app/opt/youtrack/conf"     && chown 13001:13001 "${VOL_DIR}/youtrack-app/opt/youtrack/conf"
    mkdir -p "${VOL_DIR}/youtrack-app/opt/youtrack/logs"     && chown 13001:13001 "${VOL_DIR}/youtrack-app/opt/youtrack/logs"
    mkdir -p "${VOL_DIR}/youtrack-app/opt/youtrack/backups"  && chown 13001:13001 "${VOL_DIR}/youtrack-app/opt/youtrack/backups"

    echo "Starting containers..."
    docker compose up -d

    echo "Waiting 60 seconds for services to initialize..."
    sleep 10
    if [[ "$CONFIRM" == "y" ]]; then
    echo ""
    echo "YouTrack setup: open ${YOUTRACK_APP_HOSTNAME} to complete configuration."
    echo "Authentication token (for first login):"
    echo ==============================
    docker exec youtrack-app cat /opt/youtrack/conf/internal/services/configurationWizard/wizard_token.txt
    echo ==============================
    echo ""
    fi
    echo "Done!"
    echo ""
}

if [ -f "$ENV_FILE" ]; then
    echo ".env file found. Loading existing configuration."
    load_existing_env
else
    echo ".env file not found."
fi

prompt_for_configuration
confirm_and_save_configuration
setup_containers