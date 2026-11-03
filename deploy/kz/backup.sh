#!/bin/sh
# Runs inside the `backup` container: once a day at BACKUP_HOUR (server time)
# writes a Postgres dump and a tarball of the image storage to /backups and
# deletes files older than BACKUP_KEEP_DAYS. Also does one backup at startup,
# so a broken setup shows up immediately, not at 3 a.m.
set -eu

run_backup() {
  stamp=$(date +%Y%m%d-%H%M%S)
  pg_dump --format=custom --no-owner --file="/backups/db-$stamp.dump"
  tar -C /minio-data -czf "/backups/media-$stamp.tar.gz" .
  find /backups -type f \( -name 'db-*.dump' -o -name 'media-*.tar.gz' \) \
    -mtime "+${BACKUP_KEEP_DAYS}" -delete
  echo "backup $stamp done: $(ls /backups | wc -l) files"
}

run_backup
while true; do
  now=$(date +%s)
  next=$(date -d "tomorrow ${BACKUP_HOUR}:00" +%s 2>/dev/null || true)
  if [ -z "$next" ]; then sleep 86400; else sleep $((next - now)); fi
  run_backup
done
