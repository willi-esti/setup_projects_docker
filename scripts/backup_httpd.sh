#!/bin/bash

# Usage: /opt/scripts/backup_docker_apps.sh daily
# Usage: /opt/scripts/backup_docker_apps.sh 30min

if [[ $1 != "daily" ]] &&  [[ $1 != "30min" ]]; then
    echo "Specify the argument: daily or 30min"
    exit 1
fi

today=$(date +%d%m%Y%H%M%S)

backup_dir="/opt/backup/$1"
tmp_dir="/tmp"

echo "1/10 Creating backup directory if it doesn't exist..."
mkdir -p $backup_dir

# Backup paths and filenames
declare -A backups
backups["mysql"]="$tmp_dir/mysql_$today.tgz"
backups["ovpn"]="$tmp_dir/ovpn_$today.tgz"
backups["planka_attachments"]="$tmp_dir/planka_attachments_$today.tgz"
#backups["planka_data"]="$tmp_dir/planka_data_$today.tgz"
backups["planka_project_background_images"]="$tmp_dir/planka_project_background_images_$today.tgz"
backups["planka_user_avatars"]="$tmp_dir/planka_user_avatars_$today.tgz"
#backups["wiki_data"]="$tmp_dir/wiki_data_$today.tgz"
backups["postgres_data"]="$tmp_dir/postgres_data_$today.tgz"

echo "2/10 Creating backup tarballs for MySQL volume..."
tar czf "${backups["mysql"]}" -C /var/lib/docker/volumes/mysql-data .

echo "3/10 Creating backup tarballs for OVPN volume..."
tar czf "${backups["ovpn"]}" -C /var/lib/docker/volumes/ovpn-data .

echo "4/10 Creating backup tarballs for Planka volumes..."
tar czf "${backups["planka_attachments"]}" -C /var/lib/docker/volumes/planka-attachments .
#tar czf "${backups["planka_data"]}" -C /var/lib/docker/volumes/planka-data .
tar czf "${backups["planka_project_background_images"]}" -C /var/lib/docker/volumes/planka-project-background-images .
tar czf "${backups["planka_user_avatars"]}" -C /var/lib/docker/volumes/planka-user-avatars .

echo "5/10 Creating backup tarball for Planka database..."
docker exec -it httpd-postgres-1 su postgres -c 'pg_dump -U postgres planka > /tmp/planka.sql'
docker cp httpd-postgres-1:/tmp/planka.sql $tmp_dir
tar czf "$tmp_dir/planka_$today.sql.tgz" -C $tmp_dir planka.sql
rm -f $tmp_dir/planka.sql

echo "6/10 Creating backup tarballs for Wiki.js volumes..."
#tar czf "${backups["wiki_data"]}" -C /var/lib/docker/volumes/wiki-data .
tar czf "${backups["postgres_data"]}" -C /var/lib/docker/volumes/postgres_data .

echo "7/10 Creating backup tarball for Wiki.js database..."
docker exec -it httpd-postgres-1 su postgres -c 'pg_dump -U postgres wiki > /tmp/wiki.sql'
docker cp httpd-postgres-1:/tmp/wiki.sql $tmp_dir
tar czf "$tmp_dir/wiki_$today.sql.tgz" -C $tmp_dir wiki.sql
rm -f $tmp_dir/wiki.sql

echo "8/10 Creating a final backup tarball..."
tar czf "$backup_dir/backup_$today.tgz" -C $tmp_dir ${backups[@]} "$tmp_dir/planka_$today.sql.tgz" "$tmp_dir/wiki_$today.sql.tgz"
#tar czf "$backup_dir/backup_$today.tgz" -C $tmp_dir ${backups["mysql"]} ${backups["ovpn"]} ${backups["planka_attachments"]} ${backups["planka_data"]} ${backups["planka_project_background_images"]} ${backups["planka_user_avatars"]} ${backups["planka_db"]} "$tmp_dir/planka_$today.sql.tgz" ${backups["wiki_data"]} ${backups["postgres_data"]} "$tmp_dir/wiki_$today.sql.tgz"

echo "9/10 Cleaning up temporary files..."
rm -f ${backups["mysql"]} ${backups["ovpn"]} ${backups["planka_attachments"]} ${backups["planka_data"]} ${backups["planka_project_background_images"]} ${backups["planka_user_avatars"]} ${backups["planka_db"]} "$tmp_dir/planka_$today.sql.tgz" ${backups["wiki_data"]} ${backups["postgres_data"]} "$tmp_dir/wiki_$today.sql.tgz"

echo "10/10 Managing backup retention..."
days=30
if [[ $1 == "daily" ]]; then
    days=48
fi

count=1
for i in $(ls -r $backup_dir/); do
    count=$(($count + 1))
    if [[ $count -gt $days ]]; then
        rm -f "$backup_dir/$i"
    fi
done

# Attempt to list the Google Drive accounts
account=$(/usr/local/bin/gdrive account list 2>&1)

# Check if the list command was successful
if [[ $? -ne 0 ]]; then
    echo "gdrive account list failed. Importing account configuration..."
    /usr/local/bin/gdrive account import /opt/backup/conf/gdrive_export-it_techs_fr_gmail_com.tar

    # Check if the import was successful
    if [[ $? -eq 0 ]]; then
        echo "Account configuration imported successfully."
    else
    echo "Failed to import account configuration."
    exit 1
fi
else
    echo "gdrive account list succeeded. Uploading to Gdrive:"
    
    file_id=$(/usr/local/bin/gdrive files upload "$backup_dir/backup_$today.tgz" | grep -i 'id' | awk '{print $2}' | head -n 1)


    # Check if the upload was successful
    if [[ $? -eq 0 ]]; then
        echo "Backup uploaded successfully. file_id = $file_id"
        
        # Move the backup file to a different directory on Google Drive
        /usr/local/bin/gdrive files move "$file_id" "1aQPAOOVLlErhy4cR_QkcGLhbYYRoqxBs"
        
        # Check if the move was successful
        if [[ $? -eq 0 ]]; then
            echo "Backup moved successfully."
        else
            echo "Failed to move httpd_backup."
            exit 1
        fi
    else
        echo "Failed to upload backup."
        exit 1
    fi
fi




echo "Backup process completed successfully."
