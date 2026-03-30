#!/bin/bash

# =============================================================================
# Author       : Ajay Kasturi
# Date         : March 29, 2026
# Description  : A continuous backup script that performs full, incremental,
#                and differential backups of specified file types found in
#                /home/$USER directory tree. Backups are stored in
#                ~/home/backup and logged to backup-system.log
# Usage        : ./backup-system.sh [filetype1] [filetype2] [filetype3]
# Example      : ./backup-system.sh .txt .pdf .c
# =============================================================================

# argument validation
# check if user gave more than 3 arguments (only 0 to 3 allowed)
if [ "$#" -gt 3 ]; then
	echo "usage: $0 [filetype1] [filetype2] [filetype3]"
	exit 1
fi

# main directory where the script will look for files
SEARCH_ROOT="/home/$USER"

# main backup directory where all backups will be stored
BACKUP_ROOT="$HOME/home/backup"

# directory to store full backups (complete copy of files)
FULL_BACKUP_DIR="$BACKUP_ROOT/fbup"

# directory to store incremental backups (only changes since last backup)
INCREMENTAL_BACKUP_DIR="$BACKUP_ROOT/ibup"

# directory to store differential backups (changes since last full backup)
DIFFERENTIAL_BACKUP_DIR="$BACKUP_ROOT/dbup"

# directory to store all log files
LOG_DIR="$BACKUP_ROOT/logs"

# create the log file path 
LOG_FILE="$LOG_DIR/backup-system.log"

# create a small hidden directory to store timing information for backups
STATE_DIR="$BACKUP_ROOT/.backup_state"

# file to store the time of the last full backup
LAST_FULL_REF="$STATE_DIR/last_full_ref"

# file to store the time of the last backup (used for incremental backups)
LAST_BACKUP_REF="$STATE_DIR/last_backup_ref"

# create all required directories if missing
mkdir -p "$FULL_BACKUP_DIR" \
         "$INCREMENTAL_BACKUP_DIR" \
         "$DIFFERENTIAL_BACKUP_DIR" \
         "$STATE_DIR" \
         "$LOG_DIR"

# create log file if it does not exist
touch "$LOG_FILE"

# create empty reference files if does not exist
touch "$LAST_FULL_REF" "$LAST_BACKUP_REF"

# Counters Tracking for .tar Nameing

# keep track of how many full backups have been created
full_count=1

# keep track of how many incremental backups have been created
incremental_count=1

# keep track of how many differential backups have been created
differential_count=1

# Helper Functions

# function to get the current date and time in a readable format
# example: Sun 22 Mar2026 06:16:08 PM EDT
current_timestamp() {
    date '+%a %d %b%Y %I:%M:%S %p %Z'
}

# function to add a one-line message to the log file with current date and time
log_message() {
    echo "$(current_timestamp) $1" >> "$LOG_FILE"
}

# this function finds files in the search directory based on given file types
# it prints results in a safe format (null-separated) to handle spaces in file names
find_matching_files() {
    if [ "$#" -eq 0 ]; then
        # if no file types are given, return all files
        find "$SEARCH_ROOT" -type f -not -path "$BACKUP_ROOT/*" -print0 2>/dev/null
    else
        # build conditions for file types
        local conditions=()
        for extension in "$@"; do
            # add OR (-o) between conditions if needed
            if [ "${#conditions[@]}" -gt 0 ]; then
                conditions+=("-o")
            fi
            # add condition for current file type
            conditions+=("-name" "*${extension}")
        done
        # find files that match given types
        find "$SEARCH_ROOT" -type f \( "${conditions[@]}" \) -not -path "$BACKUP_ROOT/*" -print0 2>/dev/null
    fi
}

# find files newer than a reference file
# this is used for incremental and differential backups
find_matching_files_newer_than() {
    # take the reference file
    local reference_file="$1"
    # remove the first argument so remaining ones are file types
    shift
    # if no file types are given, return all files newer than the reference file
    if [ "$#" -eq 0 ]; then
        find "$SEARCH_ROOT" -type f -newer "$reference_file" -not -path "$BACKUP_ROOT/*" -print0 2>/dev/null
    else
        # build conditions for file types
        local conditions=()
        for ext in "$@"; do
            # add OR (-o) between conditions if needed
            if [ "${#conditions[@]}" -gt 0 ]; then
                conditions+=("-o")
            fi
            # add condition for current file type
            conditions+=("-name" "*${ext}")
        done
        # find files that match given types AND are newer than reference file
        find "$SEARCH_ROOT" -type f \( "${conditions[@]}" \) -newer "$reference_file" -not -path "$BACKUP_ROOT/*" -print0 2>/dev/null
    fi
}

# this function creates a full backup of all matching files
do_full_backup() {
    # create the tar file name using the current full backup number
    local tar_name="fbup-$full_count.tar"

    # create the full path where the tar file will be saved
    local tar_path="$FULL_BACKUP_DIR/$tar_name"

    # collect all matching files into an array
    mapfile -d '' files < <(find_matching_files "$@")

    # create the tar only if there are files to archive
    if [ "${#files[@]}" -gt 0 ]; then
        printf '%s\0' "${files[@]}" | tar --null -cvf "$tar_path" --files-from=- >/dev/null 2>&1
    else
        # create an empty tar if no files match
        tar -cvf "$tar_path" --files-from /dev/null >/dev/null 2>&1
    fi

    # log the success message in the log file
    log_message "$tar_name was created"

    # update the full-backup reference time
    touch "$LAST_FULL_REF"

    # full backup is also the latest backup overall
    touch "$LAST_BACKUP_REF"

    # move to the next full backup number
    full_count=$((full_count + 1))
}

# incremental backup means:
# save only the files that changed after the most recent backup
do_incremental_backup() {
    # create the tar file name using the current incremental backup number
    local tar_name="ibup-$incremental_count.tar"

    # create the full path where the tar file will be saved
    local tar_path="$INCREMENTAL_BACKUP_DIR/$tar_name"

    # collect only the files that were changed after the last backup
    mapfile -d '' files < <(find_matching_files_newer_than "$LAST_BACKUP_REF" "$@")

    # if no files have changed, write message in log and stop this function
    if [ "${#files[@]}" -eq 0 ]; then
        log_message "No changes- IB not created"
        return
    fi

    # create a tar file containing only the changed files
    printf '%s\0' "${files[@]}" | tar --null -cvf "$tar_path" --files-from=- >/dev/null 2>&1

    # write success message in the log file
    log_message "$tar_name was created"

    # update the last backup reference time to this backup
    touch "$LAST_BACKUP_REF"

    # increase the incremental backup counter for the next tar file name
    incremental_count=$((incremental_count + 1))
}

# differential backup means:
# save only the files that changed after the most recent full backup
do_differential_backup() {
    # create the tar file name using the current differential backup number
    local tar_name="dbup-$differential_count.tar"

    # create the full path where the tar file will be saved
    local tar_path="$DIFFERENTIAL_BACKUP_DIR/$tar_name"

    # collect only the files that were changed after the last full backup
    mapfile -d '' files < <(find_matching_files_newer_than "$LAST_FULL_REF" "$@")

    # if no files have changed, write message in log and stop this function
    if [ "${#files[@]}" -eq 0 ]; then
        log_message "No changes- DB not created"
        return
    fi

    # create a tar file containing only the changed files
    printf '%s\0' "${files[@]}" | tar --null -cvf "$tar_path" --files-from=- >/dev/null 2>&1

    # write success message in the log file
    log_message "$tar_name was created"

    # update the last backup reference time to this backup
    # this is needed because the next incremental backup compares with the most recent backup
    touch "$LAST_BACKUP_REF"

    # increase the differential backup counter for the next tar file name
    differential_count=$((differential_count + 1))
}

# run the backup process continuously in a loop
while true
do
    # step 1: create a full backup of all matching files
    do_full_backup "$@"
    sleep 120   # wait for 2 minutes before next step

    # step 2: create an incremental backup (changes after step 1)
    do_incremental_backup "$@"
    sleep 120   # wait for 2 minutes

    # step 3: create a differential backup (changes after last full backup)
    do_differential_backup "$@"
    sleep 120   # wait for 2 minutes

    # step 4: create another incremental backup (changes after step 3)
    do_incremental_backup "$@"
    sleep 120   # wait for 2 minutes

    # step 5: create another differential backup (changes after last full backup)
    do_differential_backup "$@"
    sleep 120   # wait for 2 minutes

done
