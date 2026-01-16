#!/bin/bash

# --- HEX COLOR ENGINE ---
hex_fg() { echo -ne "\033[38;2;$1;$2;$3m"; }
NC='\033[0m'
C_PRIME=$(hex_fg 187 134 252)
C_ACCENT=$(hex_fg 3 218 198)
C_WARN=$(hex_fg 255 184 108)
C_DANGER=$(hex_fg 255 85 85)
C_GOSSIP=$(hex_fg 139 233 253)

# --- DIRECTORY INTELLIGENCE ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- THE JOKE VAULT ---
START_QUIPS=("Scanning for local traces..." "Securing your custom mods..." "Checking the vault status..." "Disabling the security cameras..." "Cracking the mainframe...")
MID_QUIPS=("Siphoning data..." "Loading the van..." "Merging the loot..." "Avoiding the feds..." "Handing off the encrypted drives...")
END_QUIPS=("Loot secured." "Clean getaway." "Heist complete." "The van is gone. No traces left." "Diamonds in the bag.")

RAND_START=${START_QUIPS[$RANDOM % ${#START_QUIPS[@]}]}
RAND_MID=${MID_QUIPS[$RANDOM % ${#MID_QUIPS[@]}]}
RAND_END=${END_QUIPS[$RANDOM % ${#END_QUIPS[@]}]}

# --- REPO BUNDLES ---
B_GS="16-qpr1"
B_PIX="16"

REPOS_COMMON=(
    "git@github.com:Infinity-X-Devices/device_google_gs-common.git|device/google/gs-common|$B_GS"
    "git@gitlab.com:Pyrtle93/vendor_google_camera.git|vendor/google/camera|16"
    "git@github.com:PisselShit/vendor_google_faceunlock.git|vendor/google/faceunlock|16"
    "git@github.com:crdroidandroid/android_packages_apps_PixelParts.git|packages/apps/PixelParts|16.0"
)

REPOS_P7=(
    "git@github.com:Infinity-X-Devices/device_google_gs201.git|device/google/gs201|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_pantah.git|device/google/pantah|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_lynx.git|device/google/lynx|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_cheetah.git|device/google/cheetah|15"
    "git@github.com:Infinity-X-Devices/device_google_panther.git|device/google/panther|15"
    "git@github.com:Infinity-X-Devices/vendor_google_lynx.git|vendor/google/lynx|$B_GS"
    "git@github.com:Infinity-X-Devices/vendor_google_panther.git|vendor/google/panther|$B_GS"
    "git@github.com:Infinity-X-Devices/vendor_google_cheetah.git|vendor/google/cheetah|$B_GS"
)

REPOS_P9=(
    "git@github.com:Infinity-X-Devices/device_google_caimito.git|device/google/caimito|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_zumapro.git|device/google/zumapro|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_tegu.git|device/google/tegu|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_caiman.git|device/google/caiman|$B_PIX"
    "git@github.com:Infinity-X-Devices/device_google_komodo.git|device/google/komodo|$B_PIX"
    "git@github.com:Infinity-X-Devices/device_google_tokay.git|device/google/tokay|$B_PIX"
    "git@github.com:Infinity-X-Devices/vendor_google_tokay.git|vendor/google/tokay|$B_GS"
    "git@github.com:Infinity-X-Devices/vendor_google_caiman.git|vendor/google/caiman|$B_GS"
    "git@github.com:Infinity-X-Devices/vendor_google_komodo.git|vendor/google/komodo|$B_GS"
    "git@github.com:Infinity-X-Devices/vendor_google_tegu.git|vendor/google/tegu|$B_GS"
)

# --- UTILITIES ---
check_auth() {
    ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T "git@$1" &>/dev/null
    local status=$?
    [[ $status -eq 0 || $status -eq 1 ]] && return 0 || return 1
}

# --- 1. TARGET SELECTION ---
clear
echo -e "\n${C_PRIME}🎯 SELECT YOUR TARGET HEIST:${NC}"
PS3="Choose an option (1-3): "
options=("Pixel 7 Series" "Pixel 9 Series" "Abort")
select opt in "${options[@]}"; do
    case $opt in
        "Pixel 7 Series") 
            REPOS=("${REPOS_COMMON[@]}" "${REPOS_P7[@]}")
            PURGE_LIST=("${REPOS_P9[@]}")
            break ;;
        "Pixel 9 Series") 
            REPOS=("${REPOS_COMMON[@]}" "${REPOS_P9[@]}")
            PURGE_LIST=("${REPOS_P7[@]}")
            break ;;
        "Abort") exit 1 ;;
        *) echo "Invalid choice." ;;
    esac
done

# --- 2. OFFICIAL LOGO ---
echo -e "\n${C_ACCENT}  _____        __ _        _ _                __   __"
echo -e "${C_PRIME} |_   _|      / _(_)      (_) |               \ \ / /"
echo -e "${C_GOSSIP}   | |  _ __ | |_ _ _ __  _| |_ _   _        \   / "
echo -e "${C_ACCENT}   | | | '_ \|  _| | '_ \| | __| | | |_____   > <  "
echo -e "${C_PRIME}  _| |_| | | | | | | | | | | |_| |_| |_____| /   \ "
echo -e "${C_GOSSIP} |_____|_| |_|_| |_|_| |_|_|\__|\__, |      /_/ \_\\"
echo -e "${C_ACCENT}                                |__/               ${NC}\n"

# --- 3. SANITIZATION (With Confirmation) ---
FOUND_CONFLICTS=()
for trash in "${PURGE_LIST[@]}"; do
    IFS="|" read -r _ DIR_REL _ <<< "$trash"
    if [ -d "$TOP/$DIR_REL" ]; then
        FOUND_CONFLICTS+=("$DIR_REL")
    fi
done

if [ ${#FOUND_CONFLICTS[@]} -gt 0 ]; then
    echo -e "${C_WARN}⚠️  FOUND CONFLICTING REPOS FROM THE OTHER SERIES:${NC}"
    for item in "${FOUND_CONFLICTS[@]}"; do
        echo -e "  - $item"
    done
    echo ""
    read -p "Do you want to purge these conflicting repos? (y/n): " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        for item in "${FOUND_CONFLICTS[@]}"; do
            echo -e "${C_DANGER}Removing:${NC} $item"
            rm -rf "$TOP/$item"
        done
        echo -e "${C_GOSSIP}Sanitization complete.${NC}\n"
    else
        echo -e "${C_WARN}Skipping purge. Proceeding with sync...${NC}\n"
    fi
fi

# --- 4. AUTHENTICATION ---
for vault in "github.com" "gitlab.com"; do
    echo -ne "${C_ACCENT}Handshaking with $vault... ${NC}"
    if check_auth "$vault"; then
        echo -e "${C_GOSSIP}CONNECTED.${NC}"
    else
        echo -e "${C_DANGER}PERMISSION DENIED!${NC}"
        read -p "Press [Enter] to try anyway..."
    fi
done

# --- 5. PRE-FLIGHT ---
STASH_LOG="$SCRIPT_DIR/.heist_stashes"
REPORT_FILE="$SCRIPT_DIR/.heist_report"
> "$STASH_LOG"; > "$REPORT_FILE"
trap "rm -f $STASH_LOG $REPORT_FILE; echo -e '\n${C_DANGER}ABORTED!${NC}'; exit" SIGINT SIGTERM

echo -e "\n${C_ACCENT}$RAND_START${NC}"

# --- 6. SYNC ENGINE ---
echo -e "${C_PRIME}$RAND_MID${NC}"
START_SYNC=$(date +%s)
TOTAL_REPOS=${#REPOS[@]}
current=0

for entry in "${REPOS[@]}"; do
    IFS="|" read -r REPO_URL DIR_REL REPO_BRANCH <<< "$entry"
    DIR="$TOP/$DIR_REL"
    ((current++))
    
    percent=$((current * 100 / TOTAL_REPOS))
    bar_size=$((percent / 3))
    printf "\r\033[K${C_ACCENT}▐$(hex_fg 187 134 252)%-33s${C_ACCENT}▌${NC} %d%% | ${C_GOSSIP}Cloning: %s${NC}" \
            "$(printf '█%.0s' $(seq 1 $bar_size))" "$percent" "$DIR_REL"

    # Handle Stashing
    if [ -d "$DIR/.git" ] && [[ -n $(git -C "$DIR" status --porcelain) ]]; then
        git -C "$DIR" stash push -m "Heist_Auto_Stash" --quiet
        echo "$DIR" >> "$STASH_LOG"
    fi

    # Syncing
    if [ -d "$DIR/.git" ]; then
        git -C "$DIR" remote set-url origin "$REPO_URL" &>/dev/null
        if git -C "$DIR" fetch origin "$REPO_BRANCH" --quiet && git -C "$DIR" reset --hard origin/"$REPO_BRANCH" --quiet; then
            echo -e "${C_GOSSIP}[UP TO DATE]${NC} $DIR_REL" >> "$REPORT_FILE"
        else
            echo -e "${C_DANGER}[FAILED]${NC} $DIR_REL" >> "$REPORT_FILE"
        fi
    else
        mkdir -p "$(dirname "$DIR")"
        if git clone --single-branch -b "$REPO_BRANCH" "$REPO_URL" "$DIR" --quiet; then
            echo -e "${C_ACCENT}[NEW]${NC} $DIR_REL" >> "$REPORT_FILE"
        else
            echo -e "${C_DANGER}[FAILED]${NC} $DIR_REL" >> "$REPORT_FILE"
        fi
    fi
done

# --- 7. CLEANUP & REPORT ---
[[ -s "$STASH_LOG" ]] && while read -r DIR; do git -C "$DIR" stash pop --quiet 2>/dev/null; done < "$STASH_LOG"

END_SYNC=$(date +%s)
echo -e "\n\n${C_PRIME}┌──────────────── HEIST REPORT ────────────────┐${NC}"
cat "$REPORT_FILE"
echo -e "${C_PRIME}└──────────────────────────────────────────────┘${NC}"

echo -e "\n${C_WARN}Infinity-X: $RAND_END (Total time: $((END_SYNC - START_SYNC))s)${NC}\n"
rm -f "$STASH_LOG" "$REPORT_FILE"
