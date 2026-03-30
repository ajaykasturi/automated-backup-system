# Automated Backup System

A continuous Linux backup system that performs full, incremental, and differential
backups of specified file types, with configurable filtering and timestamped logging.

## Features

- Repeats the 5-step backup cycle continuously until stopped
- Supports three backup strategies: full, incremental, and differential
- Configurable file type filtering (up to 3 file types, easily extendable)
- Maintains timestamped logging for all backup operations
- Gracefully handles no-change scenarios
- Excludes backup folders, log files, and internal state files from search results to avoid recursive backups and false positives
- Uses hidden reference timestamp files to track the latest full backup and the latest backup overall

## How It Works

The system performs a full backup first, then alternates between incremental and
differential backups every 2 minutes. Incremental backups capture files changed
since the most recent backup (full, incremental, or differential), while differential
backups capture files changed since the most recent full backup. Hidden reference
timestamp files are used to accurately track changes between each backup step.
The 5-step cycle repeats continuously until the process is stopped.

## Backup Strategies

| Type             | Description                                |
| ---------------- | ------------------------------------------ |
| **Full**         | Complete backup of all matching files      |
| **Incremental**  | Files changed since last backup (any type) |
| **Differential** | Files changed since last full backup       |

## Backup Cycle

```
Full → Incremental → Differential → Incremental → Differential → repeat
```

## Installation

```bash
# clone the repository
git clone https://github.com/ajaykasturi/automated-backup-system.git

# navigate to directory
cd automated-backup-system

# make script executable
chmod u+x backup-system.sh
```

## Usage

```bash
# run with specific file types
nohup ./backup-system.sh .txt .pdf .c &

# run with all file types
nohup ./backup-system.sh &
```

## Backup Structure

```
~/home/backup/
├── fbup/             # full backups
├── ibup/             # incremental backups
├── dbup/             # differential backups
├── logs/             # backup-system.log
└── .backup_state/    # reference files
```

## Monitoring

```bash
# view log in real time
tail -f ~/home/backup/logs/backup-system.log

# check if script is running
ps aux | grep backup-system.sh

# stop the script
pkill -f backup-system.sh
```

## Log Format

```
Sun 29 Mar2026 05:40:05 PM EDT fbup-1.tar was created
Sun 29 Mar2026 05:42:05 PM EDT No changes- IB not created
Sun 29 Mar2026 05:44:05 PM EDT dbup-1.tar was created
```

## Requirements

- Linux/Unix environment
- Bash shell
- Read/write access to home directory

## License

MIT License
