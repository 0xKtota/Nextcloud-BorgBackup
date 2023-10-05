#!/bin/bash

# ======================
# Functions Definitions
# ======================


# Function to output errors
errorecho() { cat <<< "$@" 1>&2; }

# Function to handle errors and cleanup
handle_error() {
    errorecho "ERROR: Backup failed."
    start_webserver
    exit 1
}

# ======================
# Initial Checks
# ======================

# Determine the directory containing this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if the .env file exists
if [ ! -f "$DIR/.env" ]; then
    errorecho "Error: The configuration file '.env' was not found in $DIR."
    exit 1
fi

# ======================
# Environment Setup
# ======================

# Load the .env file
source "$DIR/.env"

export BORG_PASSPHRASE
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK
export BORG_RELOCATED_REPO_ACCESS_IS_OK

# Set fileName for Backup-Db
fileNameBackupDb="${nextcloudDatabase}-db.sql"

# Define variables for the current date and its readable representation
startTime=$(date +%s)
currentDate=$(date +%Y%m%d_%H%M%S)
currentDateReadable=$(date --date @"$startTime" +"%d.%m.%Y - %H:%M:%S")

# ======================
# Root & Essential Checks
# ======================

# Check if the script is running as root
if [ "$(id -u)" != "0" ]; then
    errorecho "ERROR: This script has to be run as root!"
    exit 1
fi

# Check if essential variables are set
for var in BORG_PASSPHRASE dbPassword nextcloudDatabase dbUser localBackupDir; do
    if [ -z "${!var}" ]; then
        errorecho "ERROR: Missing $var in the configuration."
        exit 1
    fi
done

# Check if mysqldump is installed
if ! command -v mysqldump &> /dev/null; then
    errorecho "ERROR: mysqldump is not installed. Install it and try again."
    exit 1
fi

# Check if the backup directory is writable
if [ ! -w "${localBackupDir}" ]; then
    errorecho "ERROR: The backup directory ${localBackupDir} is not writable."
    exit 1
fi

# ======================
# Log Setup
# ======================

# Create the log directory if it doesn't exist
if [ ! -d "${logDirectory}" ]; then
    mkdir -p "${logDirectory}"
fi

# Set the log filename
logFile="${logDirectory}/${currentDate}.log"

# Redirect the output to the log file
exec > >(tee -i "${logFile}")
exec 2>&1

echo -e "\n###### Start of the Backup: ${currentDateReadable} ######\n"

# ======================
# Web Server Functions
# ======================

# Function to start the web server
start_webserver() {
    echo "Starting the webserver"
    systemctl start "${webserverServiceName}"
    sudo -u "${webserverUser}" php "${nextcloudFileDir}/occ" maintenance:mode --off
}

# Function to stop the web server
stop_webserver() {
    echo "Stopping apache2"
    systemctl stop "${webserverServiceName}"
    sudo -u "${webserverUser}" php "${nextcloudFileDir}/occ" maintenance:mode --on
}

# Function to start the web server but leave maintenance mode on
start_webserver_after_failure() {
    echo "Starting the webserver after failure"
    systemctl start "${webserverServiceName}"
}

# ======================
# Backup Functions
# ======================

# Function to create the database backup
backup_database() {
    echo "Creating database backup"
    if ! mysqldump --single-transaction --routines -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" > "${localBackupDir}/${fileNameBackupDb}"; then
        errorecho "Database backup failed."
        start_webserver_after_failure
        exit 1
    fi
}

# Function to create the Borg backup
create_borg_backup() {
    echo -e "\nBacking up with BorgBackup\n"
    if ! borg create --stats \
        "${borgRepository}::${currentDate}" \
        "${localBackupDir}" \
        ${borgBackupDirs}; then 
        errorecho "---> BorgBackup failed <---"
        start_webserver_after_failure
        exit 1
    fi
}

# Function to clean up old Borg backups
prune_borg_backups() {
    borg prune --progress --stats "${borgRepository}" --keep-within=7d --keep-weekly=4 --keep-monthly=6
}

# ======================
# Main Script Execution
# ======================

# Collecting data
dpkg --get-selections > "${localBackupDir}/software.list"

# Backup process
stop_webserver
backup_database
create_borg_backup
start_webserver

# Clean up old backups
prune_borg_backups

# Cleanup
rm "${localBackupDir}/software.list"
rm -r "${localBackupDir}/${fileNameBackupDb}"

# ======================
# Final Report
# ======================

endTime=$(date +%s)
endDateReadable=$(date --date @"$endTime" +"%d.%m.%Y - %H:%M:%S")
duration=$((endTime-startTime))
durationSec=$((duration % 60))
durationMin=$(((duration / 60) % 60))
durationHour=$((duration / 3600))
durationReadable=$(printf "%02d hours %02d minutes %02d seconds" $durationHour $durationMin $durationSec)

echo -e "\n###### End of the Backup: ${endDateReadable} (${durationReadable}) ######\n"
echo -e "Disk Usage:\n"
df -h "${backupDiscMount}"
