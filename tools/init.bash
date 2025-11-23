#!/usr/bin/env bash
set -Eeuo pipefail

# -------------------------------------
# YouTrack setup script
# -------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
VOL_DIR="${SCRIPT_DIR}/../vol"
BACKUP_TASKS_SRC_DIR="${SCRIPT_DIR}/../etc/limbo-backup/rsync.conf.d"
BACKUP_TASKS_DST_DIR="/etc/limbo-backup/rsync.conf.d"

REQUIRED_TOOLS="docker limbo-backup.bash"
REQUIRED_NETS="proxy-client-youtrack"
BACKUP_TASKS="10-youtrack.conf.bash"

CURRENT_YOUTRACK_VERSION="2025.2.100871"

check_requirements() {
    missed_tools=()
    for cmd in $REQUIRED_TOOLS; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missed_tools+=("$cmd")
        fi
    done

    if ((${#missed_tools[@]})); then
        echo "Required tools not found:" >&2
        for cmd in "${missed_tools[@]}"; do
            echo "  - $cmd" >&2
        done
        echo "Hint: run dev-prod-init.recipe from debian-setup-factory" >&2
        echo "Abort"
        exit 127
    fi
}

create_networks() {
    for net in $REQUIRED_NETS; do
        if docker network inspect "$net" >/dev/null 2>&1; then
            echo "Required network already exists: $net"
        else
            echo "Creating required docker network: $net (driver=bridge)"
            docker network create --driver bridge --internal "$net" >/dev/null
        fi
    done
}

create_backup_tasks() {
    for task in $BACKUP_TASKS; do
        src_file="${BACKUP_TASKS_SRC_DIR}/${task}"
        dst_file="${BACKUP_TASKS_DST_DIR}/${task}"

        if [[ ! -f "$src_file" ]]; then
            echo "Warning: backup task not found: $src_file" >&2
            continue
        fi

        cp "$src_file" "$dst_file"
        echo "Created backup task: $dst_file"
    done
}

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

    read -p "YOUTRACK_APP_HOSTNAME [${YOUTRACK_APP_HOSTNAME:-youtrack.example.com}]: " input
    YOUTRACK_APP_HOSTNAME=${input:-${YOUTRACK_APP_HOSTNAME:-youtrack.example.com}}

    read -p "YOUTRACK_JAVA_XMX [${YOUTRACK_JAVA_XMX:-2048m}]: " input
    YOUTRACK_JAVA_XMX=${input:-${YOUTRACK_JAVA_XMX:-2048m}}
}

confirm_and_save_configuration() {
    CONFIG_LINES=(
        "# YouTrack"
        "YOUTRACK_VERSION=${YOUTRACK_VERSION}"
        "YOUTRACK_APP_HOSTNAME=${YOUTRACK_APP_HOSTNAME}"
        "YOUTRACK_JAVA_XMX=${YOUTRACK_JAVA_XMX}"    
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
    while :; do
        read -p "Proceed with this configuration? (y/n): " CONFIRM
        [[ "$CONFIRM" == "y" ]] && break
        [[ "$CONFIRM" == "n" ]] && { echo "Configuration aborted by user."; exit 1; }
    done

    printf "%s\n" "${CONFIG_LINES[@]}" >"$ENV_FILE"
    echo ".env file saved to $ENV_FILE"
    echo ""
}

setup_containers() {
    echo "Stopping all containers and removing volumes..."
    docker compose down -v
       if [ -d "$VOL_DIR" ]; then
        echo "The 'vol' directory exists:"
        echo " - In case of a new install type 'y' to clear its contents. WARNING! This will remove all previous configuration files and stored data."
        echo " - In case of an upgrade/installing a new application type 'n' (or press Enter)."
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

    echo "# Managed by init.bash" > "${VOL_DIR}/youtrack-app/opt/youtrack/conf/youtrack.jvmoptions"
    echo "-Xmx${YOUTRACK_JAVA_XMX}" >> "${VOL_DIR}/youtrack-app/opt/youtrack/conf/youtrack.jvmoptions"
    chown 13001:13001 "${VOL_DIR}/youtrack-app/opt/youtrack/conf/youtrack.jvmoptions"

    echo "Starting containers..."
    docker compose up -d

    echo "Waiting 20 seconds for services to initialize..."
    sleep 20
    if [[ "$CONFIRM" == "y" ]]; then
        echo ""
        echo "YouTrack setup: open https://${YOUTRACK_APP_HOSTNAME} to complete configuration."
        echo -e "Authentication token (for first login): \033[1;32m$(docker exec youtrack-app cat /opt/youtrack/conf/internal/services/configurationWizard/wizard_token.txt)\033[0m"
        echo ""
    fi
    echo "Done!"
    echo ""
}

# -----------------------------------
# Main logic
# -----------------------------------
check_requirements

if [ -f "$ENV_FILE" ]; then
    echo ".env file found. Loading existing configuration."
    load_existing_env
else
    echo ".env file not found."
fi

prompt_for_configuration
confirm_and_save_configuration
create_networks
create_backup_tasks
setup_containers

