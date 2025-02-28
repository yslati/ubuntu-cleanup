# Ubuntu System Cleanup Script

A comprehensive system cleanup and optimization script for Ubuntu-based systems that helps free up disk space by cleaning various caches and unnecessary files.

![Ubuntu Cleanup Script](https://img.shields.io/badge/Ubuntu-Cleanup-orange)

## Overview

This script automatically cleans up various system and application caches to free up disk space on your Ubuntu system. It performs targeted cleanups across multiple applications and system components while preserving your important data and settings.

## Features

The script cleans the following areas:

- **APT Cache** - Removes downloaded package files and unnecessary packages
- **Log Files** - Cleans up old log files and optimizes journal storage
- **VS Code Cache** - Removes VS Code caches while preserving extensions and settings
- **Snap Cache** - Safely cleans snap package caches
- **Bun Cache** - Cleans Bun package manager cache
- **NPM Cache** - Cleans Node.js package manager cache
- **Firefox Cache** - Removes browser cache files while preserving your profiles
- **Chrome Cache** - Safely cleans browser cache without affecting your history or settings
- **Ubuntu Software Center Cache** - Removes downloaded packages and temporary files
- **Old Kernels** - Removes outdated kernel packages that take up space
- **systemd Journal** - Optimizes journal size and removes old entries
- **Docker** - Cleans up unused Docker images, containers, and volumes (if installed)
- **GNOME Shell Cache** - Cleans up GNOME desktop environment cache
- **Thumbnail Cache** - Removes cached thumbnails for images and files
- **Memory Cache** - Safely frees up some memory without disrupting applications

Each cleanup section displays the amount of space before and after cleanup, and a summary shows the total space saved.

## Requirements

- Ubuntu-based Linux distribution (Ubuntu, Linux Mint, Pop!_OS, etc.)
- Sudo privileges

## Installation

1. Download the script:

```bash
wget -O ubuntu-cleaner.sh https://github.com/yslati/ubuntu-cleanup/blob/master/cleanup.sh
```

2. Make it executable:

```bash
chmod +x ubuntu-cleaner.sh
```

## Usage

Run the script with sudo privileges:

```bash
sudo ./ubuntu-cleaner.sh
```

The script will:
- Display a colorful header
- Show your current system information
- Run through each cleanup section
- Show before and after sizes for each cleaned area
- Provide a summary of total space saved

All actions are logged to `/var/log/cleanup.log` for future reference.

## Safety Features

- **Non-destructive** - Preserves user data and application settings
- **Safe browser cleaning** - Only removes cache files, not history, bookmarks, or settings
- **Smart snap cleaning** - Detects Discord and Slack installations and adjusts cleanup accordingly
- **Limited memory cleaning** - Uses gentle memory cache clearing to avoid disrupting applications
- **Kernel protection** - Never removes the currently running kernel

## Customization

You can easily customize this script by modifying the following sections:

- Change the `LOG_FILE` variable to log to a different location
- Add or remove directories in the Chrome/Firefox cleanup sections
- Adjust the journal cleanup retention periods
- Add cleanup sections for other applications you use

## Scheduling Regular Cleanup

You can set up a cron job to run this script regularly:

1. Open the crontab editor:
   ```bash
   sudo crontab -e
   ```

2. Add a line to run the script weekly (e.g., every Sunday at 1 AM):
   ```bash
   0 1 * * 0 /path/to/ubuntu-cleaner.sh
   ```

## Troubleshooting

If you encounter any issues:

- Check the log file at `/var/log/cleanup.log`
- Run sections manually to identify problematic areas
- Ensure you have proper permissions for all directories
- Verify compatibility with your specific Ubuntu version

## License

This script is released under the MIT License. Feel free to modify and distribute it as needed.

## Acknowledgments

Special thanks to the Ubuntu community for tips and best practices in system maintenance.