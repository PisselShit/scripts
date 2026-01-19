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
TOP="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ ! -d "$TOP/.repo" ]; then
    echo -e "${C_DANGER}❌ ABORTING HEIST!${NC}"
    exit 1
fi

# --- UTILITIES ---
check_auth() {
    ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T "git@$1" &>/dev/null
    local status=$?
    [[ $status -eq 0 || $status -eq 1 ]] && return 0 || return 1
}

# --- THE JOKE VAULT ---
START_QUIPS=("Burning the old files..." "Securing the perimeter..." "Eliminating witnesses...")
MID_QUIPS=("Siphoning data..." "Loading the van..." "Merging the loot...")
END_QUIPS=("Loot secured." "Clean getaway." "Heist complete.")

RAND_START=${START_QUIPS[$RANDOM % ${#START_QUIPS[@]}]}
RAND_MID=${MID_QUIPS[$RANDOM % ${#MID_QUIPS[@]}]}
RAND_END=${END_QUIPS[$RANDOM % ${#END_QUIPS[@]}]}

# --- 1. TARGET SELECTION ---
clear
echo -e "\n${C_PRIME}🎯 SELECT YOUR TARGET HEIST:${NC}"
options=("Pixel 7 (Panther)" "Pixel 7 Pro (Cheetah)" "Pixel 7a (Lynx)" "Pixel 9 (Tokay)" "Pixel 9 Pro (Caiman)" "Pixel 9 Pro XL (Komodo)" "Pixel 9a (Tegu)" "Abort")

select opt in "${options[@]}"; do
    case $opt in
        "Pixel 7 (Panther)") D_FOLDER="pantah"; D_MAKEFILE="panther"; REPO_VAR="15"; FAMILY="GS201"; break ;;
        "Pixel 7 Pro (Cheetah)") D_FOLDER="pantah"; D_MAKEFILE="cheetah"; REPO_VAR="15"; FAMILY="GS201"; break ;;
        "Pixel 7a (Lynx)") D_FOLDER="lynx"; D_MAKEFILE="lynx"; REPO_VAR="16-qpr1"; FAMILY="GS201"; break ;;
        "Pixel 9 (Tokay)") D_FOLDER="caimito"; D_MAKEFILE="tokay"; REPO_VAR="16"; FAMILY="ZUMAPRO"; break ;;
        "Pixel 9 Pro (Caiman)") D_FOLDER="caimito"; D_MAKEFILE="caiman"; REPO_VAR="16"; FAMILY="ZUMAPRO"; break ;;
        "Pixel 9 Pro XL (Komodo)") D_FOLDER="caimito"; D_MAKEFILE="komodo"; REPO_VAR="16"; FAMILY="ZUMAPRO"; break ;;
        "Pixel 9a (Tegu)") D_FOLDER="tegu"; D_MAKEFILE="tegu"; REPO_VAR="16-qpr1"; FAMILY="ZUMAPRO"; break ;;
        "Abort") exit 1 ;;
    esac
done

# --- 2. TERRITORY CLEANUP ---
TO_REMOVE=()
GS201_PATHS=("$TOP/device/google/gs201" "$TOP/device/google/pantah" "$TOP/device/google/panther" "$TOP/device/google/cheetah" "$TOP/device/google/lynx" "$TOP/vendor/google/panther" "$TOP/vendor/google/cheetah" "$TOP/vendor/google/lynx" "$TOP/device/google/pantah-kernels" "$TOP/device/google/lynx-kernels")
ZUMAPRO_PATHS=("$TOP/device/google/zumapro" "$TOP/device/google/caimito" "$TOP/device/google/tokay" "$TOP/device/google/caiman" "$TOP/device/google/komodo" "$TOP/device/google/tegu" "$TOP/vendor/google/tokay" "$TOP/vendor/google/caiman" "$TOP/vendor/google/komodo" "$TOP/vendor/google/tegu" "$TOP/device/google/caimito-kernels" "$TOP/device/google/tegu-kernels")

if [ "$FAMILY" == "GS201" ]; then DIRS=("${ZUMAPRO_PATHS[@]}"); else DIRS=("${GS201_PATHS[@]}"); fi

for d in "${DIRS[@]}"; do [ -d "$d" ] && TO_REMOVE+=("$d"); done

if [ ${#TO_REMOVE[@]} -gt 0 ]; then
    echo -e "\n${C_WARN}⚠️  TERRITORY CLASH DETECTED!${NC}"
    echo -e "${C_PRIME}Found legacy files from the other family:${NC}"
    for r in "${TO_REMOVE[@]}"; do echo -e "  ${C_DANGER}➜${NC} ${r#$TOP/}"; done

    echo -ne "\n${C_DANGER}Dispose of this evidence? (y/n): ${NC}"
    read -r reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        for r in "${TO_REMOVE[@]}"; do rm -rf "$r"; done
        echo -e "${C_GOSSIP}Clean sweep complete.${NC}"
    else
        echo -e "${C_WARN}Evidence retained. Proceeding with potential contamination...${NC}"
    fi
fi

# --- 3. REPO SETUP ---
B_GS="16-qpr1"
B_LOS="lineage-23.1"

REPOS_COMMON=(
    "git@github.com:Infinity-X-Devices/device_google_gs-common.git|device/google/gs-common|$B_GS"
    "git@gitlab.com:Pyrtle93/vendor_google_camera.git|vendor/google/camera|16"
    "git@github.com:PisselShit/vendor_google_faceunlock.git|vendor/google/faceunlock|16"
    "git@github.com:crdroidandroid/android_packages_apps_PixelParts.git|packages/apps/PixelParts|16.0"
    "git@github.com:LineageOS/android_kernel_google_gs-6.1_google-modules.git|kernel/google/gs-6.1/google-modules|$B_LOS"
    "git@github.com:LineageOS/android_kernel_google_gs-6.1_devices.git|kernel/google/gs-6.1/devices|$B_LOS"
)

SPECIFIC_REPOS=(
    "git@github.com:Infinity-X-Devices/device_google_${D_FOLDER}.git|device/google/${D_FOLDER}|$B_GS"
    "git@github.com:Infinity-X-Devices/device_google_${D_MAKEFILE}.git|device/google/${D_MAKEFILE}|$REPO_VAR"
    "git@github.com:Infinity-X-Devices/vendor_google_${D_MAKEFILE}.git|vendor/google/${D_MAKEFILE}|$B_GS"
    "git@github.com:LineageOS/android_device_google_${D_FOLDER}-kernels.git|device/google/${D_FOLDER}-kernels|$B_LOS"
)

[[ "$FAMILY" == "GS201" ]] && REPOS_COMMON+=("git@github.com:Infinity-X-Devices/device_google_gs201.git|device/google/gs201|$B_GS")
[[ "$FAMILY" == "ZUMAPRO" ]] && REPOS_COMMON+=("git@github.com:Infinity-X-Devices/device_google_zumapro.git|device/google/zumapro|$B_GS")

REPOS=("${REPOS_COMMON[@]}" "${SPECIFIC_REPOS[@]}")

# --- 4. LOGO & AUTH ---
echo -e "\n${C_ACCENT}  _____        __ _        _ _                __   __"
echo -e "${C_PRIME} |_   _|      / _(_)      (_) |               \ \ / /"
echo -e "${C_GOSSIP}   | |  _ __ | |_ _ _ __  _| |_ _   _        \   / "
echo -e "${C_ACCENT}   | | | '_ \|  _| | '_ \| | __| | | |_____   > <  "
echo -e "${C_PRIME}  _| |_| | | | | | | | | | | |_| |_| |_____| /   \ "
echo -e "${C_GOSSIP} |_____|_| |_|_| |_|_| |_|_|\__|\__, |      /_/ \_\\"
echo -e "${C_ACCENT}                                |__/               ${NC}\n"

for vault in "github.com" "gitlab.com"; do
    echo -ne "${C_ACCENT}Handshaking with $vault... ${NC}"
    check_auth "$vault" && echo -e "${C_GOSSIP}CONNECTED.${NC}" || echo -e "${C_DANGER}FAILED.${NC}"
done

# --- 5. SYNC ENGINE ---
echo -e "\n${C_PRIME}󰢚 $RAND_START${NC}\n"
REPORT_FILE="$SCRIPT_DIR/.heist_report"; > "$REPORT_FILE"

for entry in "${REPOS[@]}"; do
    IFS="|" read -r REPO_URL DIR_REL REPO_BRANCH <<< "$entry"
    DIR="$TOP/$DIR_REL"
    echo -ne "${C_ACCENT}Checking ${C_GOSSIP}$DIR_REL... ${NC}"

    if [ -d "$DIR/.git" ]; then
        git -C "$DIR" remote set-url origin "$REPO_URL" &>/dev/null
        if git -C "$DIR" fetch origin "$REPO_BRANCH" --quiet && git -C "$DIR" reset --hard origin/"$REPO_BRANCH" --quiet; then
            echo -e "${C_GOSSIP}[OK]${NC}"; echo -e "UP TO DATE: $DIR_REL" >> "$REPORT_FILE"
        else echo -e "${C_DANGER}[FAIL]${NC}"; echo -e "FAILED: $DIR_REL" >> "$REPORT_FILE"; fi
    else
        [ -d "$DIR" ] && rm -rf "$DIR"
        mkdir -p "$(dirname "$DIR")"
        if git clone --single-branch -b "$REPO_BRANCH" "$REPO_URL" "$DIR" --quiet; then
            echo -e "${C_ACCENT}[NEW]${NC}"; echo -e "NEW: $DIR_REL" >> "$REPORT_FILE"
        else echo -e "${C_DANGER}[FAIL]${NC}"; echo -e "FAILED: $DIR_REL" >> "$REPORT_FILE"; fi
    fi
done

# --- 6. MAKEFILE SURGERY ---
echo -e "\n${C_GOSSIP}󰚰 $RAND_MID${NC}"
echo -ne "${C_ACCENT}Performing Surgery... ${NC}"
TARGET_MK="device-$D_MAKEFILE.mk"; FAMILY_MK="device-$D_FOLDER.mk"; MK_STATUS=""
for FILE in "$TARGET_MK" "$FAMILY_MK"; do
    MK_PATH="$TOP/device/google/$D_FOLDER/$FILE"
    if [ -f "$MK_PATH" ]; then
        if ! grep -q "\-kernels" "$MK_PATH"; then
            sed -i "s|${D_FOLDER}-kernel/|${D_FOLDER}-kernels/|g" "$MK_PATH"
            MK_STATUS+="${C_ACCENT}🔧 PATCHED: $FILE\n${NC}"
        else MK_STATUS+="${C_GOSSIP}✅ VERIFIED: $FILE already uses -kernels\n${NC}"
        fi
    fi
done
echo -e "DONE."
echo -e "$MK_STATUS"

# --- 7. KERNEL VALIDATION ---
echo -e "${C_GOSSIP}󰗠 Validating Kernel Components...${NC}"
SEARCH_PATHS=("$TOP/device/google/${D_FOLDER}-kernels" "$TOP/kernel/google/gs-6.1/devices" "$TOP/kernel/google/gs-6.1/google-modules")
FOUND_ANY=false
for K_PATH in "${SEARCH_PATHS[@]}"; do
    if [ -d "$K_PATH" ]; then
        IMG=$(find "$K_PATH" -maxdepth 3 -name "Image*" -o -name "Makefile" | head -n 1)
        if [ -n "$IMG" ]; then
            echo -e "  ${C_ACCENT}[ FOUND ]${NC} ${K_PATH#$TOP/}"
            FOUND_ANY=true
        else echo -e "  ${C_WARN}[ EMPTY ]${NC} ${K_PATH#$TOP/}"; fi
    else echo -e "  ${C_DANGER}[ MISSING ]${NC} ${K_PATH#$TOP/}"; fi
done

# --- 8. WRAP UP ---
echo -e "\n${C_PRIME}┌──────────────── HEIST REPORT ────────────────┐${NC}"
cat "$REPORT_FILE"
echo -e "${C_PRIME}└──────────────────────────────────────────────┘${NC}"
echo -e "\n${C_ACCENT}󰥻 $RAND_END${NC}"
rm -f "$REPORT_FILE"
