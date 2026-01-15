#!/bin/bash

# --- HEX COLOR ENGINE ---
hex_fg() { echo -ne "\033[38;2;$1;$2;$3m"; }
NC='\033[0m'
C_PRIME=$(hex_fg 187 134 252)  # Purple
C_ACCENT=$(hex_fg 3 218 198)   # Teal
C_WARN=$(hex_fg 255 184 108)   # Orange
C_DANGER=$(hex_fg 255 85 85)   # Red
C_GOSSIP=$(hex_fg 139 233 253) # Sky Blue

# --- DIRECTORY INTELLIGENCE ---
# This finds the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This assumes your script is in /scripts and you want repos in the parent folder
TOP="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- THE JOKE VAULT ---
START_QUIPS=("Scanning for local traces..." "Securing your custom mods..." "Checking the vault status...")
MID_QUIPS=("Siphoning data..." "Loading the van..." "Merging the loot...")
END_QUIPS=("Loot secured." "Clean getaway." "Heist complete.")

RAND_START=${START_QUIPS[$RANDOM % ${#START_QUIPS[@]}]}
RAND_MID=${MID_QUIPS[$RANDOM % ${#MID_QUIPS[@]}]}
RAND_END=${END_QUIPS[$RANDOM % ${#END_QUIPS[@]}]}

# --- SERVER INTEL ---
get_server_specs() {
    echo -e "${C_PRIME}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${C_PRIME}│${NC}  ${C_ACCENT}🖥️  SERVER INTEL${NC}                                           ${C_PRIME}│${NC}"
    echo -e "${C_PRIME}├─────────────────────────────────────────────────────────────┤${NC}"
    
    CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    CPU_CORES=$(nproc)
    echo -e "${C_PRIME}│${NC}  ${C_ACCENT}CPU:${NC} ${C_GOSSIP}${CPU_MODEL}${NC} (${CPU_CORES} Cores)"
    
    RAM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
    RAM_FREE=$(free -h | awk '/^Mem:/{print $4}')
    echo -e "${C_PRIME}│${NC}  ${C_ACCENT}RAM:${NC} ${C_GOSSIP}${RAM_TOTAL} Total${NC} (${RAM_FREE} currently free)"
    
    DISK_TOTAL=$(df -h . | awk 'NR==2 {print $2}')
    DISK_AVAIL=$(df -h . | awk 'NR==2 {print $4}')
    DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}')
    
    STORAGE_COLOR=$C_GOSSIP
    [[ ${DISK_USAGE%?} -gt 90 ]] && STORAGE_COLOR=$C_DANGER
    
    echo -e "${C_PRIME}│${NC}  ${C_ACCENT}DISK:${NC} ${STORAGE_COLOR}${DISK_AVAIL} Available${NC} / ${DISK_TOTAL} Total (${DISK_USAGE} full)"
    echo -e "${C_PRIME}└─────────────────────────────────────────────────────────────┘${NC}"
}

# --- PRE-FLIGHT ---
find "$SCRIPT_DIR" -name "index.lock" -delete 2>/dev/null
[[ ! -x "$0" ]] && chmod +x "$0"

# --- MULTI-VAULT HANDSHAKE ---
check_auth() {
    local host=$1
    echo -ne "${C_ACCENT}Handshaking with $host... ${NC}"
    ssh -T "git@$host" -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new &>/dev/null
    if [ $? -eq 255 ]; then return 1; fi
    return 0
}

# 1. INITIAL SETUP
clear
get_server_specs
echo -e "${C_WARN}Target Root: $TOP${NC}\n"

for vault in "github.com" "gitlab.com"; do
    while true; do
        if check_auth "$vault"; then
            echo -e "${C_GOSSIP}CONNECTED.${NC}"
            break
        else
            echo -e "${C_DANGER}PERMISSION DENIED!${NC}"
            read -p "Fix your SSH keys, then press [Enter] to retry..."
        fi
    done
done

GOSSIP_FILE="$SCRIPT_DIR/.gossip_data"
STASH_LOG="$SCRIPT_DIR/.heist_stashes"
> "$GOSSIP_FILE"; > "$STASH_LOG"
trap "rm -f $GOSSIP_FILE $STASH_LOG; echo -e '\n${C_DANGER}ABORTED!${NC}'; exit" SIGINT SIGTERM

# 2. OFFICIAL INFINITY-X LOGO
echo -e "${C_ACCENT}  _____        __ _       _ _               __   __"
echo -e "${C_PRIME} |_   _|      / _(_)     (_) |              \ \ / /"
echo -e "${C_GOSSIP}   | |  _ __ | |_ _ _ __  _| |_ _   _        \   / "
echo -e "${C_ACCENT}   | | | '_ \|  _| | '_ \| | __| | | |_____   > <  "
echo -e "${C_PRIME}  _| |_| | | | | | | | | | | |_| |_| |_____| /   \ "
echo -e "${C_GOSSIP} |_____|_| |_|_| |_|_| |_|_|\__|\__, |      /_/ \_\\"
echo -e "${C_ACCENT}                                |__/               ${NC}"
echo -e ""

# 3. REPO CONFIGURATION
B_GS="16-qpr1"
B_PIX="16"
REPOS=(
    "git@github.com:Infinity-X-Devices/device_google_caimito.git|device/google/caimito|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_zumapro.git|device/google/zumapro|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_lynx.git|device/google/lynx|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_pantah.git|device/google/pantah|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_gs201.git|device/google/gs201|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_gs-common.git|device/google/gs-common|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_tegu.git|device/google/tegu|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_caiman.git|device/google/caiman|$B_PIX"
    "git@github.com:Infinity-X-Devices/device_google_komodo.git|device/google/komodo|$B_PIX"
    "git@github.com:Infinity-X-Devices/device_google_tokay.git|device/google/tokay|$B_PIX"
    "git@gitlab.com:Pyrtle93/vendor_google_camera.git|vendor/google/camera|16"
    "git@github.com:PisselShit/vendor_google_faceunlock.git|vendor/google/faceunlock|16"
    "git@github.com:crdroidandroid/android_packages_apps_PixelParts.git|packages/apps/PixelParts|16.0"
    "git@github.com:Infinity-X-Devices/vendor_google_panther.git|vendor/google/panther|16"
    "git@github.com:Infinity-X-Devices/vendor_google_lynx.git|vendor/google/lynx|16"
    "git@github.com:Infinity-X-Devices/vendor_google_cheetah.git|vendor/google/cheetah|16"
    "git@github.com:Infinity-X-Devices/vendor_google_tokay.git|vendor/google/tokay|$B_GS"
    "git@github.com:Infinity-X-Devices/vendor_google_caiman.git|vendor/google/caiman|$B_GS"
    "git@github.com:Infinity-X-Devices/vendor_google_komodo.git|vendor/google/komodo|$B_GS"
    "git@github.com:Infinity-X-Devices/vendor_google_tegu.git|vendor/google/tegu|$B_GS"
)
TOTAL_REPOS=${#REPOS[@]}

# 4. CONFLICT GUARD (STASH)
echo -e "${C_ACCENT}$RAND_START${NC}"
declare -A PRE_HASHES
for entry in "${REPOS[@]}"; do
    IFS="|" read -r URL DIR_REL BRANCH <<< "$entry"
    DIR="$TOP/$DIR_REL"
    if [ -d "$DIR/.git" ]; then
        PRE_HASHES["$DIR"]=$(git -C "$DIR" rev-parse HEAD 2>/dev/null)
        if [[ -n $(git -C "$DIR" status --porcelain) ]]; then
            echo -e "  ${C_WARN}󱗘 Stashing local mods in $DIR_REL...${NC}"
            git -C "$DIR" stash push -m "Heist_Auto_Stash" --quiet
            echo "$DIR" >> "$STASH_LOG"
        fi
    fi
done

# 5. SYNC ENGINE
echo -e "${C_PRIME}$RAND_MID${NC}"
START_SYNC=$(date +%s)
current=0

for entry in "${REPOS[@]}"; do
    IFS="|" read -r REPO_URL DIR_REL REPO_BRANCH <<< "$entry"
    DIR="$TOP/$DIR_REL"
    ((current++))
    
    percent=$((current * 100 / TOTAL_REPOS))
    bar_size=$((percent / 3))
    HEX_BAR=$(hex_fg 187 134 252)
    
    printf "\r\033[K${C_ACCENT}▐${HEX_BAR}%-33s${C_ACCENT}▌${NC} ${HEX_BAR}%d%%${NC} | ${C_GOSSIP}Stolen: %s${NC}" \
           "$(printf '█%.0s' $(seq 1 $bar_size))" "$percent" "$DIR_REL"

    if [ -d "$DIR/.git" ]; then
        EXISTING_URL=$(git -C "$DIR" remote get-url origin 2>/dev/null)
        [[ "$EXISTING_URL" != "$REPO_URL" ]] && git -C "$DIR" remote set-url origin "$REPO_URL"
        
        ERR_OUT=$(git -C "$DIR" fetch origin "$REPO_BRANCH" 2>&1 --quiet && \
                  git -C "$DIR" reset --hard origin/"$REPO_BRANCH" 2>&1 --quiet)
    else
        rm -rf "$DIR"
        mkdir -p "$(dirname "$DIR")"
        ERR_OUT=$(git clone --single-branch -b "$REPO_BRANCH" "$REPO_URL" "$DIR" 2>&1 --quiet)
    fi

    if [ ! -z "$ERR_OUT" ]; then
        echo -e "\n${C_DANGER}--- INCIDENT REPORT: $DIR_REL ---${NC}"
        echo -e "${C_WARN}$ERR_OUT${NC}"
        read -p "Target halted. Press [Enter] to ignore/skip..."
        echo -e "${C_ACCENT}Resuming...${NC}"
    fi
done
echo -e "" 

# 6. RESTORE MODS & DEBRIEF
if [[ -s "$STASH_LOG" ]]; then
    echo -e "${C_ACCENT}Restoring your custom mods...${NC}"
    while read -r DIR; do
        git -C "$DIR" stash pop --quiet 2>/dev/null
    done < "$STASH_LOG"
fi

END_SYNC=$(date +%s)
TIME_ELAPSED=$((END_SYNC - START_SYNC))
TOTAL_FILES_CHANGED=0
UPDATED_COUNT=0

for entry in "${REPOS[@]}"; do
    IFS="|" read -r URL DIR_REL BRANCH <<< "$entry"
    DIR="$TOP/$DIR_REL"
    OLD_HASH=${PRE_HASHES["$DIR"]}
    if [ -d "$DIR/.git" ]; then
        NEW_HASH=$(git -C "$DIR" rev-parse HEAD 2>/dev/null)
        if [ "$OLD_HASH" != "$NEW_HASH" ]; then
            ((UPDATED_COUNT++))
            CHANGES=$(git -C "$DIR" diff --name-only "$OLD_HASH" HEAD 2>/dev/null | wc -l)
            TOTAL_FILES_CHANGED=$((TOTAL_FILES_CHANGED + CHANGES))
            MSG=$(git -C "$DIR" log -1 --pretty=format:"%s" 2>/dev/null)
            echo -e "  ${C_PRIME}•${NC} ${C_GOSSIP}$(basename "$DIR")${NC}: ${MSG:0:35}..." >> "$GOSSIP_FILE"
        fi
    fi
done

echo -e "\n${C_PRIME}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${C_PRIME}│${NC}  ${C_ACCENT}📦  INFINITY-X HEIST REPORT${NC}                               ${C_PRIME}│${NC}"
echo -e "${C_PRIME}├─────────────────────────────────────────────────────────────┤${NC}"
echo -e "${C_PRIME}│${NC}  ${C_ACCENT}INVENTORY${NC}   » [${C_GOSSIP}${UPDATED_COUNT} Stolen${NC}] [${C_PRIME}$((TOTAL_REPOS - UPDATED_COUNT)) Solid${NC}]"
echo -e "${C_PRIME}│${NC}  ${C_ACCENT}LOOT LOAD${NC}   »  ${C_GOSSIP}${TOTAL_FILES_CHANGED} files kidnapped${NC}"
echo -e "${C_PRIME}│${NC}  ${C_ACCENT}TIME${NC}        »  ${C_WARN}${TIME_ELAPSED} seconds${NC}"
if [[ -s "$GOSSIP_FILE" ]]; then
echo -e "${C_PRIME}├─────────────────────────────────────────────────────────────┤${NC}"
echo -e "${C_PRIME}│${NC}  ${C_PRIME}󰋎  THE GOSSIP COLUMN (LATEST INTEL)${NC}                      ${C_PRIME}│${NC}"
cat "$GOSSIP_FILE" | while read -r line; do printf "${C_PRIME}│${NC} %-59s ${C_PRIME}│\n" "$line"; done
fi
echo -e "${C_PRIME}└─────────────────────────────────────────────────────────────┘${NC}"

rm -f "$GOSSIP_FILE" "$STASH_LOG"
echo -e "${C_WARN}Infinity-X: $RAND_END${NC}\n"

