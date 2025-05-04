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
    local before_bytes=$(numfmt --from=iec "$before" 2>/dev/null || echo 0)
    local after_bytes=$(numfmt --from=iec "$after" 2>/dev/null || echo 0)
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

# Snap Cache Cleanup (Enhanced)
print_section "Snap Package Cleanup"
before_size=$(get_size /var/lib/snapd)
echo -e "Current total Snap size: ${RED}$before_size${NC}"

# Report current revisions
echo -e "\n${BLUE}Current snap revisions:${NC}"
snap list --all

# List current apps
active_snaps=$(snap list | awk 'NR>1 {print $1}' | sort | uniq)

# Clean old revisions
echo -e "\n${YELLOW}Removing old snap revisions...${NC}"
LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' | 
    while read snapname revision; do
        echo "Removing $snapname revision $revision"
        sudo snap remove "$snapname" --revision="$revision"
    done

# Clean snap cache
if [ -d /var/lib/snapd/cache ]; then
    echo -e "\n${YELLOW}Cleaning snap cache...${NC}"
    sudo rm -rf /var/lib/snapd/cache/*.snap
fi

# Clean out snap temp dir
if [ -d /var/lib/snapd/tmp ]; then
    sudo rm -rf /var/lib/snapd/tmp/*
fi

# Clean old seed snaps
if [ -d /var/lib/snapd/seed ]; then
    echo -e "\n${YELLOW}Cleaning seed snaps older than 1 year...${NC}"
    find /var/lib/snapd/seed -type f -name "*.snap" -mtime +365 -exec sudo rm {} \; 2>/dev/null
fi

# Clean user snap cache and trash
find ~/snap -path "*/current/.cache/*" -type f -mtime +30 -delete 2>/dev/null
find ~/snap -path "*/Trash/*" -type f -delete 2>/dev/null

after_size=$(get_size /var/lib/snapd)
echo -e "\nSnap size after cleanup: ${GREEN}$after_size${NC}"
track_cleaning "$before_size" "$after_size" "Snap Packages"

# Spotify Cleanup (for both snap and regular installations)
print_section "Spotify Cleanup"
spotify_paths=(
    "$HOME/snap/spotify"
    "$HOME/.config/spotify"
    "$HOME/.cache/spotify"
)

for path in "${spotify_paths[@]}"; do
    if [ -d "$path" ]; then
        before_size=$(get_size "$path")
        echo -e "Current Spotify data at $path: ${RED}$before_size${NC}"
        
        # Clean Spotify cache but keep current metadata
        if [ -d "$path/cache" ]; then
            find "$path/cache" -type f -mtime +30 -delete 2>/dev/null
        fi
        if [ -d "$path/Data/Browser/Cache" ]; then
            rm -rf "$path/Data/Browser/Cache"/* 2>/dev/null
        fi
        
        after_size=$(get_size "$path")
        echo -e "Spotify data after cleanup: ${GREEN}$after_size${NC}"
        track_cleaning "$before_size" "$after_size" "Spotify Cache"
    fi
done

# Discord Cleanup (for both snap and regular installations)
print_section "Discord Cleanup"
discord_paths=(
    "$HOME/snap/discord"
    "$HOME/.config/discord"
    "$HOME/.cache/discord"
)

for path in "${discord_paths[@]}"; do
    if [ -d "$path" ]; then
        before_size=$(get_size "$path")
        echo -e "Current Discord data at $path: ${RED}$before_size${NC}"
        
        # Clean Discord cache but retain login data
        if [ -d "$path/Cache" ]; then
            rm -rf "$path/Cache"/* 2>/dev/null
        fi
        if [ -d "$path/Code Cache" ]; then
            rm -rf "$path/Code Cache"/* 2>/dev/null
        fi
        if [ -d "$path/GPUCache" ]; then
            rm -rf "$path/GPUCache"/* 2>/dev/null
        fi
        
        after_size=$(get_size "$path")
        echo -e "Discord data after cleanup: ${GREEN}$after_size${NC}"
        track_cleaning "$before_size" "$after_size" "Discord Cache"
    fi
done

# Slack Cleanup (for both snap and regular installations)
print_section "Slack Cleanup"
slack_paths=(
    "$HOME/snap/slack"
    "$HOME/.config/Slack"
    "$HOME/.cache/Slack"
)

for path in "${slack_paths[@]}"; do
    if [ -d "$path" ]; then
        before_size=$(get_size "$path")
        echo -e "Current Slack data at $path: ${RED}$before_size${NC}"
        
        # Clean Slack cache but retain login data
        if [ -d "$path/Cache" ]; then
            rm -rf "$path/Cache"/* 2>/dev/null
        fi
        if [ -d "$path/Code Cache" ]; then
            rm -rf "$path/Code Cache"/* 2>/dev/null
        fi
        if [ -d "$path/GPUCache" ]; then
            rm -rf "$path/GPUCache"/* 2>/dev/null
        fi
        
        after_size=$(get_size "$path")
        echo -e "Slack data after cleanup: ${GREEN}$after_size${NC}"
        track_cleaning "$before_size" "$after_size" "Slack Cache"
    fi
done

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

# Pip Cache Cleanup
print_section "Pip Cache Cleanup"
if [ -d ~/.cache/pip ]; then
    before_size=$(get_size ~/.cache/pip)
    echo -e "Current Pip cache size: ${RED}$before_size${NC}"
    
    if command -v pip &>/dev/null; then
        pip cache purge
    else
        rm -rf ~/.cache/pip/*
    fi
    
    after_size=$(get_size ~/.cache/pip)
    echo -e "Pip cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Pip Cache"
else
    echo -e "Pip cache not found. Skipping."
fi

# Firefox Cache Cleanup
print_section "Firefox Cache Cleanup"
if [ -d ~/.mozilla/firefox ]; then
    before_size=$(get_size ~/.mozilla/firefox)
    echo -e "Current Firefox cache size: ${RED}$before_size${NC}"
    
    # Find Firefox profiles and clean their caches
    find ~/.mozilla/firefox -name "*.default*" -type d | while read profile; do
        if [ -d "$profile/cache2" ]; then
            rm -rf "$profile/cache2"
        fi
        if [ -d "$profile/storage/default" ]; then
            find "$profile/storage/default" -type f -mtime +30 -delete
        fi
        if [ -d "$profile/thumbnails" ]; then
            rm -rf "$profile/thumbnails"/*
        fi
    done
    
    after_size=$(get_size ~/.mozilla/firefox)
    echo -e "Firefox cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Firefox Cache"
else
    echo -e "Firefox cache not found. Skipping."
fi

# Chrome/Chromium Cache Cleanup (Enhanced)
print_section "Chrome/Chromium Cache Cleanup"
chrome_paths=(
    "$HOME/.cache/google-chrome"
    "$HOME/.config/google-chrome"
    "$HOME/.cache/chromium"
    "$HOME/.config/chromium"
)

for chrome_path in "${chrome_paths[@]}"; do
    if [ -d "$chrome_path" ]; then
        before_size=$(get_size "$chrome_path")
        echo -e "Current Chrome/Chromium data at $chrome_path: ${RED}$before_size${NC}"
        
        # Find all profiles (Default, Profile 1, etc.)
        find "$chrome_path" -maxdepth 1 -type d -name "Default" -o -name "Profile*" | while read profile; do
            echo -e "Cleaning profile: ${BLUE}$(basename "$profile")${NC}"
            
            # Clean specific cache directories
            cache_dirs=(
                "Cache/Cache_Data"
                "Code Cache/js"
                "GPUCache"
                "Media Cache"
                "Service Worker/CacheStorage"
                "Service Worker/ScriptCache"
                "Applications Cache"
            )
            
            for dir in "${cache_dirs[@]}"; do
                cache_path="$profile/$dir"
                if [ -d "$cache_path" ]; then
                    rm -rf "$cache_path"/* 2>/dev/null
                fi
            done
        done
        
        after_size=$(get_size "$chrome_path")
        echo -e "Chrome/Chromium data after cleanup: ${GREEN}$after_size${NC}"
        track_cleaning "$before_size" "$after_size" "Chrome/Chromium Cache"
    fi
done

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
    # Get initial docker size (this is approximate)
    before_size=$(docker system df | awk 'NR==2 {print $4}')
    echo -e "Current Docker data size: ${RED}$before_size${NC}"
    
    # Remove unused containers, networks, and dangling images
    echo "Removing unused containers, networks, images..."
    docker system prune -f
    
    # Remove unused volumes (with warning)
    echo -e "${YELLOW}Warning: This will remove all unused volumes. Proceed? (y/n)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
    fi
    
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

# TypeScript Cleanup
print_section "TypeScript Cache Cleanup"
if [ -d ~/.cache/typescript ]; then
    before_size=$(get_size ~/.cache/typescript)
    echo -e "Current TypeScript cache size: ${RED}$before_size${NC}"
    rm -rf ~/.cache/typescript/*
    after_size=$(get_size ~/.cache/typescript)
    echo -e "TypeScript cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "TypeScript Cache"
else
    echo -e "TypeScript cache not found. Skipping."
fi

# Node Gyp Cache Cleanup
print_section "Node Gyp Cache Cleanup"
if [ -d ~/.cache/node-gyp ]; then
    before_size=$(get_size ~/.cache/node-gyp)
    echo -e "Current Node Gyp cache size: ${RED}$before_size${NC}"
    rm -rf ~/.cache/node-gyp/*
    after_size=$(get_size ~/.cache/node-gyp)
    echo -e "Node Gyp cache size after cleanup: ${GREEN}$after_size${NC}"
    track_cleaning "$before_size" "$after_size" "Node Gyp Cache"
else
    echo -e "Node Gyp cache not found. Skipping."
fi

# Mesa Shader Cache Cleanup
print_section "Mesa Shader Cache Cleanup"
mesa_cache_dirs=(
    "$HOME/.cache/mesa_shader_cache"
    "$HOME/.cache/mesa_shader_cache_db"
)

for dir in "${mesa_cache_dirs[@]}"; do
    if [ -d "$dir" ]; then
        before_size=$(get_size "$dir")
        echo -e "Current Mesa shader cache size ($dir): ${RED}$before_size${NC}"
        # Only delete files older than 30 days to keep recent performance benefits
        find "$dir" -type f -mtime +30 -delete 2>/dev/null
        after_size=$(get_size "$dir")
        echo -e "Mesa shader cache size after cleanup: ${GREEN}$after_size${NC}"
        track_cleaning "$before_size" "$after_size" "Mesa Shader Cache"
    fi
done

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
    if [ "$bytes" -gt 0 ]; then
        cleaned_human=$(numfmt --to=iec "$bytes")
        echo -e "${BLUE}$section:${NC} $cleaned_human"
    fi
done

total_cleaned_human=$(numfmt --to=iec "$total_bytes")
echo -e "\n${GREEN}Total space cleaned: $total_cleaned_human${NC}"

# Get final free space
final_free=$(df -h / | awk 'NR==2 {print $4}')
echo -e "Final free space: $final_free"

# Print footer
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Cleanup process completed successfully!${NC}"
echo -e "\n${YELLOW}Note: For further disk usage analysis, run 'sudo apt install ncdu' and then run 'ncdu /' to find other large files${NC}"