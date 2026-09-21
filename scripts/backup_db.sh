#!/usr/bin/env bash
set -euo pipefail

# Переходим в корень репозитория, чтобы docker compose нашёл compose.yaml
cd "$(dirname "$0")/.."

BACKUP_DIR="backups"
DATE=$(date +%F)
KEEP_DAYS=7

mkdir -p "$BACKUP_DIR"

docker compose exec -T postgres-oltp pg_dump -U minipay -d minipay_oltp -Fc > "$BACKUP_DIR/minipay_oltp_$DATE.dump"
docker compose exec -T postgres-dwh pg_dump -U minipay -d minipay_dwh -Fc > "$BACKUP_DIR/minipay_dwh_$DATE.dump"

# Удаляем дампы старше KEEP_DAYS суток (только если всё выше прошло успешно)
find "$BACKUP_DIR" -name "*.dump" -mtime +"$KEEP_DAYS" -delete

echo "$(date '+%F %T') backup OK"
