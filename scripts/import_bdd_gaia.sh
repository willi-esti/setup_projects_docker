#!/bin/bash

# Base64 decode
base64 -d /opt/httpd/gaia/backup_only_needed.s.d.txt > /tmp/backup_only_needed.s.tgz
# Decrypt the backup file
openssl enc -d -aes-256-cbc -in /tmp/backup_only_needed.s.tgz -out /tmp/backup_only_needed.tgz
gpg --output /tmp/backup_only_needed.tgz --decrypt /tmp/backup_only_needed.s.tgz
# if the decryption fails, exit
if [ $? -ne 0 ]; then
    exit 1
fi

# Extract the contents of the decrypted backup file
tar xzf /tmp/backup_only_needed.tgz -C /tmp/
rm -f /tmp/backup_only_needed.tgz

# Extract the individual backup files
tar xzf /tmp/planka_attachments.tgz -C /var/lib/docker/volumes/
tar xzf /tmp/planka.sql.tgz -C /tmp/
tar xzf /tmp/wiki.sql.tgz -C /tmp/
rm -f /tmp/planka_attachments.tgz /tmp/planka.sql.tgz /tmp/wiki.sql.tgz

# Restore the Planka database
# if the docker is running, use it
if docker inspect planka-postgres-1 > /dev/null 2>&1; then
    docker cp /tmp/planka.sql planka-postgres-1:/tmp/
    docker exec -it planka-postgres-1 su postgres -c 'psql -U postgres -d planka -f /tmp/planka.sql'
    rm -f /tmp/planka.sql
fi

docker cp /tmp/planka.sql planka-postgres-1:/tmp/
docker exec -it planka-postgres-1 su postgres -c 'psql -U postgres -d planka -f /tmp/planka.sql'
rm -f /tmp/planka.sql

# Restore the Wiki.js database
# if the docker is running, use it
if docker inspect wikijs-db-1 > /dev/null 2>&1; then
    docker cp /tmp/wiki.sql wikijs-db-1:/tmp/
    docker exec -it wikijs-db-1 su postgres -c 'psql -U postgres -d wiki -f /tmp/wiki.sql'
    rm -f /tmp/wiki.sql
fi
