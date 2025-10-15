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
