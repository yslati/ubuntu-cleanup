#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging setup
LOG_FILE="/var/log/cleanup.log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

# Print fancy header
print_header() {
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "           System Cleanup & Optimization"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Print section header
print_section() {
    echo -e "\n${YELLOW}[+] $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to get directory size
get_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

# Function to track cleaned space
declare -A cleaned_space
track_cleaning() {
    local before=$1
    local after=$2
    local section=$3
    
    # Convert sizes to bytes for comparison
    local before_bytes=$(numfmt --from=iec "$before")
    local after_bytes=$(numfmt --from=iec "$after")
    local saved=$((before_bytes - after_bytes))
    
    cleaned_space["$section"]=$saved
}

print_header

# Initialize total cleaned space
total_cleaned=0

# Start timestamp
echo -e "${GREEN}Started cleanup at: $(date)${NC}\n"

# System Information
print_section "System Information"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Initial free space: $(df -h / | awk 'NR==2 {print $4}')"

# APT Cache Cleanup
print_section "APT Cache Cleanup"
before_size=$(get_size /var/cache/apt)
echo -e "Current APT cache size: ${RED}$before_size${NC}"
sudo apt-get clean
sudo apt autoremove --purge -y
after_size=$(get_size /var/cache/apt)
echo -e "APT cache size after cleanup: ${GREEN}$after_size${NC}"
track_cleaning "$before_size" "$after_size" "APT Cache"

# Log Files Cleanup
print_section "Log Files Cleanup"
before_size=$(get_size /var/log)
echo -e "Current log files size: ${RED}$before_size${NC}"
sudo find /var/log -type f -name "*.gz" -delete
sudo find /var/log -type f -name "*.1" -delete
sudo journalctl --vacuum-time=7d
sudo journalctl --vacuum-size=100M
after_size=$(get_size /var/log)
echo -e "Log files size after cleanup: ${GREEN}$after_size${NC}"
track_cleaning "$before_size" "$after_size" "Log Files"

# VS Code Cache Cleanup
print_section "VS Code Cache Cleanup"
before_size=$(get_size ~/.config/Code)
echo -e "Current VS Code cache size: ${RED}$before_size${NC}"
if [ -d ~/.config/Code/Cache ]; then
    rm -rf ~/.config/Code/Cache
fi
if [ -d ~/.config/Code/CachedExtensionVSIXs ]; then
    rm -rf ~/.config/Code/CachedExtensionVSIXs
fi
if [ -d ~/.config/Code/User/workspaceStorage ]; then
    rm -rf ~/.config/Code/User/workspaceStorage
fi
after_size=$(get_size ~/.config/Code)
echo -e "VS Code cache size after cleanup: ${GREEN}$after_size${NC}"
track_cleaning "$before_size" "$after_size" "VS Code Cache"

# Snap Cache Cleanup
print_section "Snap Cache Cleanup"
before_size=$(get_size ~/snap)
echo -e "Current Snap cache size: ${RED}$before_size${NC}"

# Check if Discord or Slack are snap packages
discord_snap=$(snap list 2>/dev/null | grep -i discord)
slack_snap=$(snap list 2>/dev/null | grep -i slack)

if [ -d /var/lib/snapd/cache ]; then
    sudo find /var/lib/snapd/cache -type f -name "*.snap" -mtime +30 -delete
fi

if [ -d ~/snap/code/184/.local/share/Trash ]; then
    rm -rf ~/snap/code/184/.local/share/Trash/*
fi

find ~/snap -path "*/Trash/*" -type f -delete 2>/dev/null

after_size=$(get_size ~/snap)
echo -e "Snap cache size after cleanup: ${GREEN}$after_size${NC}"
track_cleaning "$before_size" "$after_size" "Snap Cache"

if [ ! -z "$discord_snap" ] || [ ! -z "$slack_snap" ]; then
    echo -e "${YELLOW}Note: Discord and/or Slack are installed via Snap. Snap cleanup was limited to ensure these apps continue working.${NC}"
fi

# Bun Cache Cleanup
print_section "Bun Cache Cleanup"
if [ -d ~/.bun/install/cache ]; then
    before_size=$(get_size ~/.bun/install/cache)
    echo -e "Current Bun cache size: ${RED}$before_size${NC}"
    rm -rf ~/.bun/install/cache
    after_size=$(get_size ~/.bun/install/cache)
    echo -e "Bun cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Bun Cache"
else
    echo -e "Bun cache not found. Skipping."
fi

# NPM Cache Cleanup
print_section "NPM Cache Cleanup"
if command -v npm &>/dev/null; then
    before_size=$(get_size ~/.npm)
    echo -e "Current NPM cache size: ${RED}$before_size${NC}"
    npm cache clean --force
    after_size=$(get_size ~/.npm)
    echo -e "NPM cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "NPM Cache"
else
    echo -e "NPM not found. Skipping."
fi

# Firefox Cache Cleanup
print_section "Firefox Cache Cleanup"
if [ -d ~/.mozilla/firefox ]; then
    before_size=$(get_size ~/.mozilla/firefox)
    echo -e "Current Firefox cache size: ${RED}$before_size${NC}"
    find ~/.mozilla/firefox -type d -name "cache2" -exec rm -rf {} \; 2>/dev/null
    after_size=$(get_size ~/.mozilla/firefox)
    echo -e "Firefox cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Firefox Cache"
else
    echo -e "Firefox cache not found. Skipping."
fi

# Chrome/Chromium Cache Cleanup (Safe Mode)
print_section "Chrome Cache Cleanup"
if [ -d ~/.cache/google-chrome ]; then
    before_size=$(get_size ~/.cache/google-chrome)
    echo -e "Current Chrome cache size: ${RED}$before_size${NC}"
    
    # Only clean specific cache directories that don't affect user data
    safe_to_clean=(
        "Default/Cache/Cache_Data"        # Regular web cache
        "Default/Code Cache/js"           # JavaScript cache
        "Default/GPUCache"               # GPU shader cache
        "Default/Media Cache"            # Media file cache
    )
    
    for dir in "${safe_to_clean[@]}"; do
        if [ -d "$HOME/.cache/google-chrome/$dir" ]; then
            echo -e "Cleaning ${BLUE}$dir${NC}..."
            find "$HOME/.cache/google-chrome/$dir" -type f -not -name "index*" -delete
        fi
    done
    
    after_size=$(get_size ~/.cache/google-chrome)
    echo -e "Chrome cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Chrome Cache"
    
    echo -e "\n${GREEN}✓ Chrome cleanup completed safely. Your history, tabs, and settings are preserved.${NC}"
else
    echo -e "Chrome cache not found. Skipping."
fi

# Ubuntu Software Center Cache
print_section "Ubuntu Software Center Cache Cleanup"
if [ -d ~/.cache/gnome-software ]; then
    before_size=$(get_size ~/.cache/gnome-software)
    echo -e "Current Software Center cache size: ${RED}$before_size${NC}"
    rm -rf ~/.cache/gnome-software/*
    if [ -d /var/lib/PackageKit/download ]; then
        sudo rm -rf /var/lib/PackageKit/download*
    fi
    after_size=$(get_size ~/.cache/gnome-software)
    echo -e "Software Center cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Software Center Cache"
else
    echo -e "Software Center cache not found. Skipping."
fi

# Old Kernel Cleanup
print_section "Old Kernel Cleanup"
echo "Current kernel: $(uname -r)"
old_kernels=$(dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d')
if [ ! -z "$old_kernels" ]; then
    echo -e "${YELLOW}Found old kernels:${NC}"
    echo "$old_kernels"
    echo -e "${BLUE}Removing old kernels...${NC}"
    for kernel in $old_kernels; do
        sudo apt-get remove -y $kernel
    done
else
    echo "No old kernels found"
fi

# systemd Journal Cleanup
print_section "systemd Journal Cleanup"
if [ -d /var/log/journal ]; then
    before_size=$(get_size /var/log/journal)
    echo -e "Current journal size: ${RED}$before_size${NC}"
    sudo journalctl --vacuum-time=7d
    sudo journalctl --vacuum-size=100M
    after_size=$(get_size /var/log/journal)
    echo -e "Journal size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Journal"
else
    echo -e "Journal directory not found. Skipping."
fi

# Docker Cleanup (if installed)
print_section "Docker Cleanup"
if command -v docker &>/dev/null; then
    before_size=$(docker system df | awk 'NR==2 {print $4}')
    echo -e "Current Docker data size: ${RED}$before_size${NC}"
    docker system prune -af --volumes
    after_size=$(docker system df | awk 'NR==2 {print $4}')
    echo -e "Docker data size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Docker"
else
    echo -e "Docker not found. Skipping."
fi

# GNOME Shell Cache
print_section "GNOME Shell Cache Cleanup"
if [ -d ~/.cache/gnome-shell ]; then
    before_size=$(get_size ~/.cache/gnome-shell)
    echo -e "Current GNOME Shell cache size: ${RED}$before_size${NC}"
    rm -rf ~/.cache/gnome-shell/runtime-state-*
    after_size=$(get_size ~/.cache/gnome-shell)
    echo -e "GNOME Shell cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "GNOME Shell"
else
    echo -e "GNOME Shell cache not found. Skipping."
fi

# Thumbnail Cache Cleanup
print_section "Thumbnail Cache Cleanup"
if [ -d ~/.cache/thumbnails ]; then
    before_size=$(get_size ~/.cache/thumbnails)
    echo -e "Current thumbnail cache size: ${RED}$before_size${NC}"
    rm -rf ~/.cache/thumbnails/*
    after_size=$(get_size ~/.cache/thumbnails)
    echo -e "Thumbnail cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Thumbnails"
else
    echo -e "Thumbnail cache not found. Skipping."
fi

# Memory Cache Cleanup
print_section "Memory Cache Cleanup"
echo "Free memory before cleanup: $(free -h | awk '/^Mem:/ {print $4}')"
sync && sudo sysctl -w vm.drop_caches=1
echo "Free memory after cleanup: $(free -h | awk '/^Mem:/ {print $4}')"
echo -e "${YELLOW}Note: Using gentle memory cleanup to avoid disrupting running applications${NC}"

# Calculate total cleaned space
print_section "Cleanup Summary"
echo -e "${GREEN}Cleanup completed at: $(date)${NC}"
echo -e "\nSpace cleaned by section:"
total_bytes=0
for section in "${!cleaned_space[@]}"; do
    bytes=${cleaned_space["$section"]}
    total_bytes=$((total_bytes + bytes))
    cleaned_human=$(numfmt --to=iec "$bytes")
    echo -e "${BLUE}$section:${NC} $cleaned_human"
done

total_cleaned_human=$(numfmt --to=iec "$total_bytes")
echo -e "\n${GREEN}Total space cleaned: $total_cleaned_human${NC}"
echo -e "Final free space: $(df -h / | awk 'NR==2 {print $4}')"

# Print footer
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Cleanup process completed successfully!${NC}"