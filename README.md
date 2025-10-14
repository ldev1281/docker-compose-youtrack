# YouTrack Docker Compose Deployment (with Caddy Reverse Proxy)

This repository provides a production-ready Docker Compose configuration for deploying [YouTrack](https://www.jetbrains.com/youtrack/) — a self-hosted issue tracker and project management platform by JetBrains.  
The stack integrates with Caddy reverse proxy for automatic HTTPS and persistent data storage.

---

## Setup Instructions

### 1. Clone the Repository

Clone the project to your server in the `/docker/youtrack/` directory:

```bash
mkdir -p /docker/youtrack
cd /docker/youtrack
git clone https://github.com/ldev1281/docker-compose-youtrack.git .
```

### 2. Create Docker Network and Set Up Reverse Proxy

This project is designed to work with the reverse proxy configuration provided by [`docker-compose-caddy`](https://github.com/ldev1281/docker-compose-caddy). To enable this integration, follow these steps:

1. **Create the shared Docker network** (if it doesn't already exist):

    ```bash
    docker network create --driver bridge proxy-client-youtrack
    ```

2. **Set up the Caddy reverse proxy** by following the instructions in the [`docker-compose-caddy`](https://github.com/ldev1281/docker-compose-caddy) repository.

Once Caddy is installed, it will automatically detect the YouTrack container via the `proxy-client-youtrack` network and route traffic accordingly.

---

### 3. Configure and Start the Application

Configuration Variables:

| Variable Name              | Description                                   | Default Value             |
|----------------------------|-----------------------------------------------|----------------------------|
| `YOUTRACK_VERSION`         | Docker image tag for YouTrack                 | `2025.2.100871`           |
| `YOUTRACK_APP_HOSTNAME`    | Public domain name for YouTrack               | `youtrack.example.com`    |

To configure and launch all required services, run the provided script:

```bash
./tools/init.bash
```

The script will:

- Prompt you to enter configuration values (press `Enter` to accept defaults).
- Generate the `.env` file.
- Optionally clear existing data volumes.
- Create the necessary directories with correct permissions.
- Start the containers and wait for initialization.

**Important:**  
After initialization, the script will display your **first login token**, required for YouTrack’s setup wizard.

---

### 4. Start the YouTrack Service

```bash
docker compose up -d
```

This will start YouTrack and make it available at the configured domain.

---

### 5. Verify Running Containers

```bash
docker compose ps
```

You should see the `youtrack-app` container running.

---

### 6. Persistent Data Storage

YouTrack uses the following bind-mounted volumes for data persistence:

- `./vol/youtrack-app/opt/youtrack/data` — YouTrack data  
- `./vol/youtrack-app/opt/youtrack/conf` — Configuration files  
- `./vol/youtrack-app/opt/youtrack/logs` — Log files  
- `./vol/youtrack-app/opt/youtrack/backups` — Internal backups  

---

### Example Directory Structure

```
/docker/youtrack/
├── docker-compose.yml
├── .env
├── tools/
│   └── init.bash
└── vol/
    └── youtrack-app/
        └── opt/
            └── youtrack/
                ├── backups/
                ├── conf/
                ├── data/
                └── logs/
```

---

## Creating a Backup Task for YouTrack

To create a backup task for your YouTrack deployment using [`backup-tool`](https://github.com/jordimock/backup-tool), add a new task file to `/etc/limbo-backup/rsync.conf.d/`:

```bash
sudo nano /etc/limbo-backup/rsync.conf.d/10-youtrack.conf.bash
```

Paste the following contents:

```bash
CMD_BEFORE_BACKUP="docker compose --project-directory /docker/youtrack down"
CMD_AFTER_BACKUP="docker compose --project-directory /docker/youtrack up -d"

CMD_BEFORE_RESTORE="docker compose --project-directory /docker/youtrack down || true"
CMD_AFTER_RESTORE=(
  "docker network create --driver bridge proxy-client-youtrack || true"
  "docker compose --project-directory /docker/youtrack up -d"
)

INCLUDE_PATHS=(
  "/docker/youtrack"
)
```

---

## License

Licensed under the Prostokvashino License. See [LICENSE](LICENSE) for details.