#!/bin/bash

# --- HEX COLOR ENGINE ---
hex_fg() { echo -ne "\033[38;2;$1;$2;$3m"; }
NC='\033[0m'
C_PRIME=$(hex_fg 187 134 252); C_ACCENT=$(hex_fg 3 218 198)
C_WARN=$(hex_fg 255 184 108); C_DANGER=$(hex_fg 255 85 85); C_GOSSIP=$(hex_fg 139 233 253)

# --- UTILITIES ---
check_auth() {
    ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T "git@$1" &>/dev/null
    local status=$?
    [[ $status -eq 0 || $status -eq 1 ]] && return 0 || return 1
}

# --- DIRECTORY INTELLIGENCE ---
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
CURRENT_DIR="$(dirname "$SCRIPT_PATH")"
TEMP_TOP="$CURRENT_DIR"
while [[ "$TEMP_TOP" != / && ! -d "$TEMP_TOP/.repo" ]]; do TEMP_TOP="$(dirname "$TEMP_TOP")"; done
[ -d "$TEMP_TOP/.repo" ] && TOP="$TEMP_TOP" || { echo -e "${C_DANGER} [!] NO REPO ROOT FOUND${NC}"; exit 1; }

# --- THE JOKE VAULT ---
START_QUIPS=("Initiating neural handshake..." "Cracking the mainframe..." "Scanning vulnerabilities...")
END_QUIPS=("System synchronized." "The heist was a success." "Loot secured.")
RAND_START=${START_QUIPS[$RANDOM % ${#START_QUIPS[@]}]}
RAND_END=${END_QUIPS[$RANDOM % ${#END_QUIPS[@]}]}

# --- TARGET SELECTION ---
clear
echo -e "${C_ACCENT}  _____        __ _        _ _                __   __"
echo -e "${C_PRIME} |_   _|      / _(_)      (_) |                \ \ / /"
echo -e "${C_GOSSIP}   | |  _ __ | |_ _ _ __  _| |_ _   _        \   / "
echo -e "${C_ACCENT}   | | | '_ \|  _| | '_ \| | __| | | |_____   > <  "
echo -e "${C_PRIME}  _| |_| | | | | | | | | | | |_| |_| |_____| /   \ "
echo -e "${C_GOSSIP} |_____|_| |_|_| |_|_| |_|_|\__|\__, |      /_/ \_\\"
echo -e "${C_ACCENT}                                |__/               ${NC}"

options=("Pixel 7 (Panther)" "Pixel 7 Pro (Cheetah)" "Pixel 7a (Lynx)" "Pixel 9 (Tokay)" "Pixel 9 Pro (Caiman)" "Pixel 9 Pro XL (Komodo)" "Pixel 9a (Tegu)" "Abort")
select opt in "${options[@]}"; do
    case $opt in
        "Pixel 7 (Panther)") D_FOLDER="pantah"; D_MAKEFILE="panther"; REPO_VAR="15"; FAMILY="GS201"; K_VER="6.1"; break ;;
        "Pixel 7 Pro (Cheetah)") D_FOLDER="pantah"; D_MAKEFILE="cheetah"; REPO_VAR="15"; FAMILY="GS201"; K_VER="6.1"; break ;;
        "Pixel 7a (Lynx)") D_FOLDER="lynx"; D_MAKEFILE="lynx"; REPO_VAR="16-qpr1"; FAMILY="GS201"; K_VER="6.1"; break ;;
        "Pixel 9 (Tokay)") D_FOLDER="caimito"; D_MAKEFILE="tokay"; REPO_VAR="16"; FAMILY="ZUMAPRO"; K_VER="6.1"; break ;;
        "Pixel 9 Pro (Caiman)") D_FOLDER="caimito"; D_MAKEFILE="caiman"; REPO_VAR="16"; FAMILY="ZUMAPRO"; K_VER="6.1"; break ;;
        "Pixel 9 Pro XL (Komodo)") D_FOLDER="caimito"; D_MAKEFILE="komodo"; REPO_VAR="16"; FAMILY="ZUMAPRO"; K_VER="6.1"; break ;;
        "Pixel 9a (Tegu)") D_FOLDER="tegu"; D_MAKEFILE="tegu"; REPO_VAR="16"; FAMILY="ZUMAPRO"; K_VER="6.1"; break ;;
        "Abort") exit 1 ;;
    esac
done

# --- TERRITORY CLEANUP ---
TO_REMOVE=()
GS201_PATHS=("${TOP}/device/google/gs201" "${TOP}/device/google/pantah" "${TOP}/device/google/panther" "${TOP}/device/google/cheetah" "${TOP}/device/google/lynx" "${TOP}/vendor/google/panther" "${TOP}/vendor/google/cheetah" "${TOP}/vendor/google/lynx" "${TOP}/device/google/pantah-kernels" "${TOP}/device/google/lynx-kernels")
ZUMAPRO_PATHS=("${TOP}/device/google/zumapro" "${TOP}/device/google/caimito" "${TOP}/device/google/tokay" "${TOP}/device/google/caiman" "${TOP}/device/google/komodo" "${TOP}/device/google/tegu" "${TOP}/vendor/google/tokay" "${TOP}/vendor/google/caiman" "${TOP}/vendor/google/komodo" "${TOP}/vendor/google/tegu" "${TOP}/device/google/caimito-kernels" "${TOP}/device/google/tegu-kernels")

if [ "$FAMILY" == "GS201" ]; then DIRS=("${ZUMAPRO_PATHS[@]}"); else DIRS=("${GS201_PATHS[@]}"); fi

for d in "${DIRS[@]}"; do [ -d "$d" ] && TO_REMOVE+=("$d"); done

if [ ${#TO_REMOVE[@]} -gt 0 ]; then
    echo -e "\n${C_DANGER} [!] TERRITORY CLASH DETECTED!${NC}"
    echo -e "${C_PRIME}Found conflicting legacy intelligence from the other family:${NC}"
    echo -e "${C_GOSSIP}------------------------------------------------------------${NC}"
    for r in "${TO_REMOVE[@]}"; do 
        echo -e "  ${C_WARN}*${NC} ${r#$TOP/} ${C_DANGER}[CONFLICT]${NC}"
    done
    echo -e "${C_GOSSIP}------------------------------------------------------------${NC}"

    echo -ne "\n${C_DANGER} >> Dispose of this evidence? (y/n): ${NC}"
    read -r reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        echo -e "${C_ACCENT} [*] Purging legacy data...${NC}"
        for r in "${TO_REMOVE[@]}"; do rm -rf "$r"; done
        echo -e "${C_GOSSIP} [V] Clean sweep complete. Territory secured.${NC}"
    fi
fi

# --- SYNC WORKER (With Stash-and-Bring-Back) ---
sync_worker() {
    local URL=$1 DIR_REL=$2 BRANCH=$3
    local DIR="$TOP/$DIR_REL"
    local STASHED=false
    
    [ -d "$DIR" ] && [ ! -d "$DIR/.git" ] && rm -rf "$DIR"
    
    if [ -d "$DIR/.git" ]; then
        if ! git -C "$DIR" diff --quiet || ! git -C "$DIR" diff --cached --quiet; then
            echo -e "  ${C_WARN}>> [STASHING]${NC} Local changes in $DIR_REL"
            git -C "$DIR" stash push -m "Heist_Sync_Protect" --quiet
            STASHED=true
        fi
        
        git -C "$DIR" fetch origin "$BRANCH" --quiet
        if git -C "$DIR" rebase origin/"$BRANCH" --quiet; then
            echo -e "  ${C_ACCENT}>> [OK]${NC} $DIR_REL"
            if [ "$STASHED" = true ]; then
                git -C "$DIR" stash pop --quiet &>/dev/null
                echo -e "     ${C_GOSSIP}  ↳ [RESTORED]${NC} Local edits reapplied."
            fi
        else
            echo -e "  ${C_DANGER}>> [FAIL]${NC} $DIR_REL (Rebase conflict)"
            git -C "$DIR" rebase --abort &>/dev/null
        fi
    else
        mkdir -p "$(dirname "$DIR")"
        git clone --single-branch -b "$BRANCH" "$URL" "$DIR" --quiet && echo -e "  ${C_ACCENT}>> [NEW]${NC} $DIR_REL"
    fi
}

# --- REPO LIST ---
B_GS="16-qpr1"; B_LOS="lineage-23.1";
REPOS=(
    "git@github.com:Infinity-X-Devices/device_google_gs-common.git|device/google/gs-common|$B_GS"
    "git@gitlab.com:Pyrtle93/vendor_google_camera.git|vendor/google/camera|16"
    "git@github.com:PisselShit/vendor_google_faceunlock.git|vendor/google/faceunlock|16"
    "git@github.com:crdroidandroid/android_packages_apps_PixelParts.git|packages/apps/PixelParts|16.0"
    "git@github.com:Infinity-X-Devices/device_google_${D_FOLDER}.git|device/google/${D_FOLDER}|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_${D_MAKEFILE}.git|device/google/${D_MAKEFILE}|$REPO_VAR"
    "git@github.com:Infinity-X-Devices/vendor_google_${D_MAKEFILE}.git|vendor/google/${D_MAKEFILE}|$B_GS"
    "https://github.com/LineageOS/android_device_google_${D_FOLDER}-kernels.git|device/google/${D_FOLDER}-kernels|$B_LOS"
    "https://github.com/LineageOS/android_kernel_google_gs-6.1_manifest.git|kernel/google/gs-6.1/manifest|$B_LOS"
    "git@github.com:LineageOS/android_kernel_google_gs-6.1_google-modules.git|kernel/google/gs-6.1/google-modules|$B_LOS"
    "git@github.com:LineageOS/android_kernel_google_gs-6.1_devices.git|kernel/google/gs-6.1/devices|$B_LOS"
)
[[ "$FAMILY" == "GS201" ]] && REPOS+=("git@github.com:Infinity-X-Devices/device_google_gs201.git|device/google/gs201|$B_GS")
[[ "$FAMILY" == "ZUMAPRO" ]] && REPOS+=("git@github.com:Infinity-X-Devices/device_google_zumapro.git|device/google/zumapro|$B_GS")

# --- PRE-FLIGHT AUTH CHECK ---
echo -e "\n${C_GOSSIP} [+] Checking secure connections...${NC}"
CHECK_HOSTS=("github.com" "gitlab.com")
for host in "${CHECK_HOSTS[@]}"; do
    if check_auth "$host"; then
        echo -e "  ${C_ACCENT}>> [AUTH OK]${NC} Connection to $host verified."
    else
        echo -e "  ${C_DANGER}>> [AUTH FAIL]${NC} Cannot reach $host via SSH."
        echo -e "    ${C_WARN}Ensure your SSH keys are added to your agent (ssh-add).${NC}"
        echo -ne "${C_PRIME}Proceed anyway? (y/N): ${NC}"
        read -r auth_resp
        [[ ! "$auth_resp" =~ ^([yY][eE][sS]|[yY])$ ]] && exit 1
    fi
done

# --- EXECUTION ---
echo -e "\n${C_PRIME} >>> $RAND_START${NC}\n"
for entry in "${REPOS[@]}"; do
    IFS="|" read -r URL REL BRANCH <<< "$entry"
    sync_worker "$URL" "$REL" "$BRANCH" & 
done
wait

# --- THE ULTIMATE INTEL AUDIT ---
echo -e "\n${C_GOSSIP} [SCAN] Performing Deep Intelligence Sweep...${NC}"

# --- Private Space & Config Scan ---
K_PRIVATE="$TOP/kernel/google/gs-6.1/private"
if [ -d "$K_PRIVATE" ]; then
    echo -e "  ${C_ACCENT}[ VERIFIED ]${NC} Private Space: $K_PRIVATE"
    for subdir in "devices" "google-modules"; do
        [ -d "$K_PRIVATE/$subdir" ] && echo -e "                ${C_ACCENT}↳ [ OK ]${NC} Found sub-intel: $subdir" || echo -e "                ${C_DANGER}↳ [ MISSING ]${NC} Critical sub-intel: $subdir"
    done
fi

# --- Kernel Binary Search ---
K_PREBUILT="$TOP/device/google/${D_FOLDER}-kernels/$K_VER"
if [ -d "$K_PREBUILT" ]; then
    echo -e "  ${C_ACCENT}[ VERIFIED ]${NC} Kernel Prebuilts folder detected."
    K_IMG_FILE=$(find "$K_PREBUILT" -maxdepth 1 \( -name "Image*" -o -name "kernel*" \) -type f -printf "%f\n" | head -n 1)
    DTB_COUNT=$(find "$K_PREBUILT" -name "*.dtb" | wc -l)
    KO_COUNT=$(find "$K_PREBUILT" -name "*.ko" | wc -l)
    
    if [ -n "$K_IMG_FILE" ]; then
        echo -e "                ↳ Image: ${C_ACCENT}$K_IMG_FILE${NC} | DTBs: $DTB_COUNT | Modules: $KO_COUNT"
    else
        echo -e "                ↳ Image: ${C_DANGER}MISSING${NC} | DTBs: $DTB_COUNT | Modules: $KO_COUNT"
        echo -e "                  ${C_WARN}   (Check: device/google/${D_FOLDER}-kernels/README for naming)${NC}"
    fi
fi

echo -e "\n${C_ACCENT} <<< $RAND_END${NC}\n"

# --- AUTO-LUNCH ---
echo -ne "${C_GOSSIP} >> Initialize Environment & Lunch infinity_${D_MAKEFILE}? (y/N): ${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "\n${C_PRIME} >> Select Build Type:${NC}"
    build_types=("user" "userdebug" "eng")
    select btype in "${build_types[@]}"; do
        case $btype in
            "user"|"userdebug"|"eng") buildtype=$btype; break ;;
            *) echo "Invalid choice. Select 1-3." ;;
        esac
    done

    cd "$TOP"
    source build/envsetup.sh
    lunch "infinity_${D_MAKEFILE}-${buildtype}"
    /bin/bash
else
    echo -e "${C_WARN} >> Heist concluded. Manual build required.${NC}"
fi
