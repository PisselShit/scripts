#!/bin/bash

CONF="config.conf"
BOOKMARKS_FILE="bookmarks.txt"
LAST_SESSION=".last_session"
PROFILE_DIR="profiles"
BANNER_DIR="banners"
REPO_URL="https://raw.githubusercontent.com/PisselShit/scripts/main/rom_manager.sh"

CYAN='\033[0;36m'
PURPLE='\033[1;38;5;141m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

[ ! -d "$PROFILE_DIR" ] && mkdir -p "$PROFILE_DIR"
[ ! -d "$BANNER_DIR" ] && mkdir -p "$BANNER_DIR"
[ ! -f "$BOOKMARKS_FILE" ] && touch "$BOOKMARKS_FILE"
[ ! -f "$LAST_SESSION" ] && touch "$LAST_SESSION"

show_hint() {
    echo -e "────────────────────────"
    case $1 in
        "tg")
            echo -e "${YELLOW}💡 HINT: TELEGRAM IDS${NC}"
            echo -e "• User: 12345678"
            echo -e "• Channel: -100123456789" ;;
        "paths")
            echo -e "${YELLOW}💡 HINT: BUILD PATHS${NC}"
            echo -e "• Standard: ~/android/lineage" ;;
        "sf")
            echo -e "${YELLOW}💡 HINT: SOURCEFORGE${NC}"
            echo -e "• Format: user@frs.sourceforge.net" ;;
    esac
    echo -e "────────────────────────"
}

check_dependencies() {
    echo -e "${CYAN}🔍 Checking environment...${NC}"
    local deps=("curl" "rsync" "rclone" "unzip" "ssh" "jq" "convert")
    local missing=()
    for tool in "${deps[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  MISSING TOOLS:${NC}"
        for m in "${missing[@]}"; do echo -e " • $m"; done
        read -p "Install now? (y/n): " inst_choice
        if [[ "$inst_choice" =~ ^[Yy]$ ]]; then
            sudo apt update && sudo apt install -y curl rsync rclone unzip ssh jq imagemagick
        fi
    fi
}

check_updates() {
    echo -e "${CYAN}🔄 Checking updates...${NC}"
    REMOTE_VER=$(curl -s "$REPO_URL" | grep -m1 "Version:" | awk '{print $3}')
    CURRENT_VER="4.4"
    if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "$CURRENT_VER" ]; then
        echo -e "${YELLOW}✨ New Version: $REMOTE_VER${NC}"
        read -p "Update now? (y/n): " up_choice
        if [[ "$up_choice" =~ ^[Yy]$ ]]; then
            curl -s "$REPO_URL" -o "$0"
            chmod +x "$0"
            exec "$0"
        fi
    fi
}

get_device_banner() {
    local dev=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local found_banner=""
    for ext in png jpg jpeg; do
        if [ -f "$BANNER_DIR/${dev}.$ext" ]; then
            found_banner="$BANNER_DIR/${dev}.$ext"
            break
        fi
    done
    if [ -z "$found_banner" ] && command -v convert &> /dev/null; then
        local gen_path="$BANNER_DIR/${dev}_auto.png"
        # Always re-generate if testing/previewing to ensure theme update
        convert -size 1200x630 gradient:"${THEME_GRADIENT:-#3494E6-#EC6EAD}" \
            -font DejaVu-Sans-Bold -fill white -pointsize 90 -gravity center -draw "text 0,-60 '${SAVED_ROM:-$DEFAULT_BRAND}'" \
            -pointsize 55 -fill "white" -draw "text 0,60 'Device: ${dev^^}'" \
            -pointsize 30 -fill "#eeeeee" -draw "text 0,180 'Build Date: $(date +%Y-%m-%d)'" \
            "$gen_path"
        found_banner="$gen_path"
    fi
    echo "${found_banner:-$TG_BANNER_PATH}"
}

send_telegram() {
    local rom_name="$1" dev="$2" ver="$3" status="$4" file="$5" size="$6" md5="$7" dl_url="$8" notes="$9" preview_only="${10}"
    local msg="🚀 *New Build Ready!*\n\n📦 *ROM:* $rom_name\n🔢 *Version:* $ver\n📱 *Device:* $dev\n👤 *Maintainer:* $MAINTAINER_NAME\n🛡 *Status:* $status\n📊 *Size:* $size\n🔐 *MD5:* \`$md5\`"
    [ -n "$notes" ] && msg+="\n\n📝 *Changelog:*\n$notes"
    [ -n "$TG_FOOTER" ] && msg+="\n\n$TG_FOOTER"
    [ "$preview_only" == "true" ] && msg="🖼 *Banner Preview Mode*\nThis is a test of your current theme/gradient."
    
    local buttons="[{\"text\":\"⬇️ Download Now\",\"url\":\"$dl_url\"}]"
    [ -n "$TG_SUPPORT_LINK" ] && buttons="${buttons},[{\"text\":\"💬 Support Group\",\"url\":\"$TG_SUPPORT_LINK\"}]"
    local kb="{\"inline_keyboard\":[$buttons]}"
    
    local active_banner=$(get_device_banner "$dev")
    IFS=',' read -ra TARGETS <<< "$TG_CHAT_ID"
    for ID in "${TARGETS[@]}"; do
        ID=$(echo $ID | xargs)
        local method="sendMessage"; local photo_param=""
        if [ -n "$active_banner" ] && [ -f "$active_banner" ]; then
            method="sendPhoto"; photo_param="-F photo=@$active_banner"
        fi
        curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/$method" $photo_param -F "chat_id=$ID" -F "parse_mode=Markdown" -F "$([ "$method" == "sendPhoto" ] && echo "caption" || echo "text")=$(echo -e "$msg")" -F "reply_markup=$kb" > /dev/null
    done
}

get_rom_version() {
    local version=$(unzip -p "$1" META-INF/com/android/metadata 2>/dev/null | grep "post-build=" | cut -d/ -f4)
    [ -z "$version" ] && version=$(echo "$(basename "$1")" | grep -oP 'v\d+\.\d+|v\d+|\d+\.\d+' | head -n 1)
    echo "${version:-"3.7"}"
}

detect_active_device() {
    local product_dir="$BASE_SEARCH_ROOT/out/target/product"
    [ -d "$product_dir" ] && find "$product_dir" -maxdepth 2 -name "*.zip" -printf '%T+ %p\n' 2>/dev/null | sort -r | head -n 1 | awk '{print $2}' | cut -d/ -f6
}

check_and_fix_connections() {
    clear; echo -e "${PURPLE}⚡ CONNECTION DIAGNOSTICS${NC}"
    if [ "$PROVIDER_TYPE" == "SF" ]; then
        show_hint "sf"
        ssh -o BatchMode=yes -o ConnectTimeout=8 -T "${REMOTE_PATH%%:*}" 2>&1 | grep -q "welcome" && echo -e "${GREEN}✅ SSH: OK${NC}" || echo -e "${RED}❌ SSH: FAIL${NC}"
    else
        rclone lsd "$REMOTE_PATH" --max-depth 1 &>/dev/null && echo -e "${GREEN}✅ Rclone: OK${NC}" || echo -e "${RED}❌ Rclone: FAIL${NC}"
    fi
    read -p "Press Enter..."
}

run_seamless_setup() {
    clear; echo -e "${PURPLE}🌟 SEAMLESS SETUP GUIDE${NC}"
    echo -e "────────────────────────"
    echo -e "STEP 1: STORAGE"
    echo -e "1) Google Drive"
    echo -e "2) SourceForge"
    read -p "Select [2]: " p_sel; p_sel=${p_sel:-2}
    if [ "$p_sel" == "1" ]; then
        PROVIDER="GD"
        read -p "Rclone Remote [drive]: " r_in; REMOTE_URL="${r_in:-drive}:"
        read -p "Cloud Folder: " b_in; BASE_FOLDER=${b_in:-"Builds"}
    else
        PROVIDER="SF"; show_hint "sf"
        read -p "SF User: " sf_user
        read -p "SF Project: " sf_proj
        REMOTE_URL="${sf_user}@frs.sourceforge.net:/home/frs/project/${sf_proj}"
        BASE_FOLDER="ROM"
    fi

    echo -e "\nSTEP 2: PROJECT INFO"
    read -p "ROM Name: " r_name; BRAND_ROM=${r_name:-"Project"}
    read -p "Maintainer: " m_name; MAINTAINER_VAL=${m_name:-"$USER"}
    show_hint "paths"
    read -p "Root Path: " b_path; BUILD_PATH=${b_path:-"$HOME/android"}

    echo -e "\nSTEP 3: BANNER THEME"
    echo -e "1) 🌊 Ocean (Blue)"
    echo -e "2) 🌸 Blossom (Pink)"
    echo -e "3) 🌋 Vulcan (Red)"
    echo -e "4) 🌿 Forest (Green)"
    echo -e "5) ✍️ Custom Hex Codes"
    read -p "Select [2]: " t_sel; t_sel=${t_sel:-2}
    case $t_sel in
        1) T_GRAD="#2193b0-#6dd5ed" ;;
        3) T_GRAD="#434343-#000000" ;;
        4) T_GRAD="#11998e-#38ef7d" ;;
        5) echo -e "Format: #Hex1-#Hex2"
           read -p "Hex: " T_GRAD ;;
        *) T_GRAD="#3494E6-#EC6EAD" ;;
    esac

    echo -e "\nSTEP 4: TELEGRAM"
    read -p "Enable TG? (y/n) [y]: " tg_en
    if [[ ! "$tg_en" =~ ^[Nn]$ ]]; then
        TG_ENABLED="ENABLED"
        read -p "Bot Token: " b_token
        show_hint "tg"
        read -p "Chat ID(s): " c_id
        read -p "Support Link: " s_link
    else
        TG_ENABLED="DISABLED"
    fi

    cat << EOF > $CONF
PROVIDER_TYPE="$PROVIDER"
REMOTE_PATH="$REMOTE_URL"
CLOUD_BASE="$BASE_FOLDER"
DEFAULT_BRAND="$BRAND_ROM"
MAINTAINER_NAME="$MAINTAINER_VAL"
BASE_SEARCH_ROOT="$BUILD_PATH"
TG_TOKEN="$b_token"
TG_CHAT_ID="$c_id"
SF_PROJ="$sf_proj"
TG_SUPPORT_LINK="$s_link"
THEME_GRADIENT="$T_GRAD"
PROJECT_STATUS="ENABLED"
TG_NOTIFY="$TG_ENABLED"
TG_BANNER_PATH=""
TG_FOOTER=""
EOF
    echo -e "${GREEN}Config Saved!${NC}"; sleep 1; exec "$0"
}

check_dependencies
[ ! -f "$CONF" ] && run_seamless_setup || { source "$CONF"; check_updates; }

while true; do
    source "$CONF" 2>/dev/null; [ -s "$LAST_SESSION" ] && source "$LAST_SESSION"
    S_IND=$([ "$PROJECT_STATUS" == "ENABLED" ] && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
    T_IND=$([ "$TG_NOTIFY" == "ENABLED" ] && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
    clear; echo -e "${PURPLE}🚀 ${SAVED_ROM:-$DEFAULT_BRAND} MANAGER${NC}"
    echo -e "────────────────────────"
    echo -e "1) 📤 UPLOAD & POST"
    echo -e "2) 📂 BOOKMARKS"
    echo -e "3) ⚙️ CONFIG"
    echo -e "4) 👥 PROFILES"
    echo -e "────────────────────────"
    echo -e "s) Status: $S_IND"
    echo -e "t) TG Notify: $T_IND"
    echo -e "r) Reset Template"
    echo -e "w) Factory Reset"
    echo -e "0) ❌ EXIT"
    echo -e "────────────────────────"
    read -p "Select: " choice
    case $choice in
        0) echo -e "Are you sure?"
           echo -e "y) Yes"
           echo -e "n) No"
           read -p "Selection: " c; [[ "$c" =~ ^[Yy]$ ]] && exit 0 ;;
        r) echo -e "Are you sure?"
           echo -e "y) Yes"
           echo -e "n) No"
           read -p "Selection: " c; [[ "$c" =~ ^[Yy]$ ]] && { rm -f "$LAST_SESSION" "$BOOKMARKS_FILE"; exec "$0"; } ;;
        w) echo -e "Are you sure?"
           echo -e "y) Yes"
           echo -e "n) No"
           read -p "Selection: " c; [[ "$c" =~ ^[Yy]$ ]] && { rm -f "$CONF"; exec "$0"; } ;;
        s) [[ "$PROJECT_STATUS" == "ENABLED" ]] && v="DISABLED" || v="ENABLED"
           sed -i "s|PROJECT_STATUS=.*|PROJECT_STATUS=\"$v\"|" $CONF; continue ;;
        t) [[ "$TG_NOTIFY" == "ENABLED" ]] && v="DISABLED" || v="ENABLED"
           sed -i "s|TG_NOTIFY=.*|TG_NOTIFY=\"$v\"|" $CONF; continue ;;
        1)
            clear; echo -e "${CYAN}📤 UPLOADER${NC}"
            if [ -n "$SAVED_ROM" ]; then
                echo -e "Reuse '$SAVED_ROM'?"
                echo -e "y) Yes"
                echo -e "n) No"
                read -p "Selection: " reuse
                [[ "$reuse" =~ ^[Yy]$ ]] && PROJECT_DIR="$SAVED_ROM" || { read -p "Name: " PROJECT_DIR; }
            else
                read -p "Project Name: " PROJECT_DIR
            fi
            echo "SAVED_ROM=\"$PROJECT_DIR\"" > "$LAST_SESSION"
            echo -e "\nSOURCE:"
            echo -e "1) 🔍 Auto"
            echo -e "2) 📂 Bookmarks"
            echo -e "3) ✍️ Manual"
            read -p "Select [1]: " src_choice
            case ${src_choice:-1} in
                2) cat -n "$BOOKMARKS_FILE"; read -p "Index: " b_idx; SEARCH_DIR=$(sed -n "${b_idx}p" "$BOOKMARKS_FILE") ;;
                3) read -p "Path: " SEARCH_DIR ;;
                *) AD=$(detect_active_device); read -p "Device [$AD]: " d_in; DEVICE=${d_in:-$AD}
                   SEARCH_DIR="$BASE_SEARCH_ROOT/out/target/product/$DEVICE" ;;
            esac
            FILES=($(find "$SEARCH_DIR" -maxdepth 2 -type f \( -name "*.zip" -o -name "*.json" \) ! -name "*ota*" 2>/dev/null | xargs ls -t))
            if [ ${#FILES[@]} -gt 0 ]; then
                for i in "${!FILES[@]}"; do echo " $((i+1))) $(basename "${FILES[$i]}")"; done
                read -p "Select [1]: " f_idx; f_idx=$(( ${f_idx:-1} - 1 )); ZIP="${FILES[$f_idx]}"
                FN=$(basename "$ZIP"); SZ=$(du -h "$ZIP" | awk '{print $1}'); MD=$(md5sum "$ZIP" | awk '{print $1}'); VR=$(get_rom_version "$ZIP")
                [ "$PROVIDER_TYPE" == "SF" ] && URL="https://sourceforge.net/projects/$SF_PROJ/files/$FN/download" || URL="https://drive.google.com/drive/search?q=$FN"
                echo -e "\n${YELLOW}📝 Changelog (Ctrl+D):${NC}"; NOTES=$(timeout 60s cat)
                if [ "$PROVIDER_TYPE" == "SF" ]; then
                    rsync -avP -z -e ssh --inplace "$ZIP" "${REMOTE_PATH}${CLOUD_BASE}/"
                else
                    rclone copyto "$ZIP" "${REMOTE_PATH}${CLOUD_BASE}/$FN" --progress
                fi
                if [ "$TG_NOTIFY" == "ENABLED" ]; then
                    [[ "$FN" =~ [Oo][Ff][Ff][Ii][Cc][Ii][Aa][Ll] ]] && ST="✅ Official" || ST="🛠 Unofficial"
                    send_telegram "${PROJECT_DIR^^}" "${DEVICE^^}" "$VR" "$ST" "$FN" "$SZ" "$MD" "$URL" "$NOTES"
                fi
            else
                echo -e "${RED}❌ Not found!${NC}"; sleep 2
            fi ;;
        3) while true; do clear; echo -e "${PURPLE}⚙️ CONFIG${NC}"
               echo -e "1) Chat IDs"
               echo -e "2) ID Discovery"
               echo -e "3) Maintainer"
               echo -e "4) Diagnostics"
               echo -e "5) 🖼 Preview Banner"
               echo -e "b) BACK"
               read -p "Select: " q; [[ "$q" == "b" ]] && break;
               case $q in
                    1) show_hint "tg"; read -p "IDs: " ids; sed -i "s|^TG_CHAT_ID=.*|TG_CHAT_ID=\"$ids\"|" $CONF ;;
                    2) echo -e "Post msg to group, press Enter..."; read
                       curl -s "https://api.telegram.org/bot$TG_TOKEN/getUpdates" | jq -r '.result[] | "ID: \(.message.chat.id // .channel_post.chat.id) | Title: \(.message.chat.title // .channel_post.chat.title)"' | uniq; read -p "Enter..." ;;
                    3) read -p "Name: " m_n; sed -i "s|^MAINTAINER_NAME=.*|MAINTAINER_NAME=\"$m_n\"|" $CONF ;;
                    4) check_and_fix_connections ;;
                    5) echo -e "Generating test banner..."
                       rm -f "$BANNER_DIR/test_auto.png"
                       send_telegram "PREVIEW" "TEST" "4.4" "✅ Test" "test.zip" "0MB" "000" "http://test.com" "" "true"
                       echo -e "${GREEN}Banner sent to Telegram!${NC}"; sleep 2 ;;
               esac; done ;;
        2) while true; do clear; echo -e "${PURPLE}📂 BOOKMARKS${NC}"; cat -n "$BOOKMARKS_FILE"
               echo -e "──────────────────"
               echo -e "a) Add Current"
               echo -e "d) Delete"
               echo -e "b) Back"
               read -p "Select: " cmd; [[ "$cmd" == "b" ]] && break;
               [[ "$cmd" == "a" ]] && echo "$(pwd)" >> "$BOOKMARKS_FILE"
               [[ "$cmd" == "d" ]] && { read -p "Index: " idx; sed -i "${idx}d" "$BOOKMARKS_FILE"; }; done ;;
        4) while true; do clear; echo -e "${PURPLE}👥 PROFILES${NC}"
               files=("$PROFILE_DIR"/*.conf); i=1
               [ -e "${files[0]}" ] && for f in "${files[@]}"; do echo "$i) $(basename "$f" .conf)"; ((i++)); done
               echo -e "──────────────────"
               echo -e "s) Save Current"
               echo -e "b) Back"
               read -p "Select: " p_c; [[ "$p_c" == "b" ]] && break;
               if [[ "$p_c" == "s" ]]; then
                   read -p "Name: " n; cp "$CONF" "$PROFILE_DIR/${n,,}.conf"
               else
                   [ -n "$p_c" ] && sel="${files[$((p_c-1))]}"; [ -f "$sel" ] && { echo -e "Load Profile?"; echo -e "y) Yes"; echo -e "n) No"; read -p "Selection: " c; [[ "$c" =~ ^[Yy]$ ]] && { cp "$sel" "$CONF"; exec "$0"; }; }; fi; done ;;
    esac
done
