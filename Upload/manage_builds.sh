#!/bin/bash

# --- 0. DIRECTORY & FILE MANAGEMENT ---
mkdir -p "Upload"
CONF="Upload/config.conf"
BOOKMARKS_FILE="Upload/bookmarks.txt"
LAST_SESSION="Upload/.last_session"
WIZARD_STATE="Upload/.setup_state" 
touch "$BOOKMARKS_FILE" "$LAST_SESSION"

# --- 1. SMART DETECTION & VERSION EXTRACTION ---
DETECTED_BRAND=$(basename "$(pwd)" | sed 's/[-_]//g' | tr '[:lower:]' '[:upper:]')
[ -d "build/make" ] && DETECTED_ROOT=$(pwd) || DETECTED_ROOT="$HOME/android"
GIT_USER=$(git config user.name)
DEFAULT_MAINTAINER=${GIT_USER:-"Community"}

get_rom_version() {
    local zip_file="$1"
    local version=$(unzip -p "$zip_file" META-INF/com/android/metadata 2>/dev/null | grep "post-build=" | cut -d/ -f4)
    if [ -z "$version" ]; then
        version=$(echo "$(basename "$zip_file")" | grep -oP 'v\d+\.\d+|v\d+|\d+\.\d+' | head -n 1)
    fi
    echo "${version:-"Unknown"}"
}

detect_active_device() {
    local product_dir="$BASE_SEARCH_ROOT/out/target/product"
    if [ -d "$product_dir" ]; then
        local latest_dev=$(find "$product_dir" -maxdepth 2 -name "*.zip" -printf '%T+ %p\n' | sort -r | head -n 1 | awk '{print $2}' | cut -d/ -f6)
        echo "$latest_dev"
    fi
}

# --- 2. SSH KEY HELPER ---
show_ssh_instructions() {
    echo -e "\033[1;38;2;3;218;198m🚀 HOW TO ENABLE PASSWORDLESS UPLOADS:\033[0m"
    echo -e "\033[1;38;5;141m──────────────────────────────────────────────────\033[0m"
    echo "1. Copy the key displayed below."
    echo "2. Go to SourceForge > Account Settings > SSH Keys."
    echo "3. Paste the key and save."
    echo -e "\033[1;38;5;141m──────────────────────────────────────────────────\033[0m"
}

check_ssh_key() {
    clear
    show_ssh_instructions
    if [ -f ~/.ssh/id_ed25519.pub ]; then KEY_PATH="$HOME/.ssh/id_ed25519.pub"
    elif [ -f ~/.ssh/id_rsa.pub ]; then KEY_PATH="$HOME/.ssh/id_rsa.pub"
    else
        echo -e "\n\033[1;33mHint: SSH keys allow uploading to SourceForge without a password.\033[0m"
        read -p "No SSH key found. Generate one? (y/n): " gen_key
        if [[ "$gen_key" =~ ^[Yy]$ ]]; then ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519; KEY_PATH="$HOME/.ssh/id_ed25519.pub"
        else return 1; fi
    fi
    [ -n "$KEY_PATH" ] && cat "$KEY_PATH"
    echo -e "\033[1;38;5;141m──────────────────────────────────────────────────\033[0m"
    read -p "Key copied/ready? (y/n): " ssh_ready
    [[ "$ssh_ready" =~ ^[Yy]$ ]] && return 0 || return 1
}

# --- 3. TELEGRAM & CHANGELOG ---
upload_to_paste() {
    local content="$1"
    local paste_url=$(curl -s -X POST https://spaceb.in/api/v1/documents/ -H "Content-Type: application/json" -d "{\"content\": \"$content\", \"extension\": \"txt\"}" | grep -oP '(?<="key":")[^"]+')
    [ -n "$paste_url" ] && echo "https://spaceb.in/$paste_url" || echo "FAILED"
}

generate_auto_changelog() {
    if [ -d ".git" ]; then
        local logs=$(git log --oneline -n 15 --no-merges)
        upload_to_paste "$logs"
    else echo "FAILED"; fi
}

send_telegram() {
    local banner="$1" dev="$2" ver="$3" status="$4" file="$5" size="$6" md5="$7" dl_url="$8" notes_url="$9" kb method="sendMessage" photo_param=""
    
    [[ ! "$dl_url" =~ ^http ]] && dl_url="https://sourceforge.net/projects/$SF_PROJ/files"

    # CRITICAL: Using the variable explicitly loaded from config
    local msg="🚀 *New Build Ready!*\n\n📦 *ROM:* $banner\n🔢 *Version:* $ver\n📱 *Device:* $dev\n👤 *Maintainer:* $MAINTAINER_NAME\n🛡 *Status:* $status\n📊 *Size:* $size\n🔐 *MD5:* \`$md5\`"
    
    [ -n "$TG_FOOTER" ] && msg="${msg}\n\n$TG_FOOTER"
    
    if [ -n "$notes_url" ] && [[ "$notes_url" =~ ^http ]]; then
        kb="{\"inline_keyboard\":[[{\"text\":\"⬇️ Download Now\",\"url\":\"$dl_url\"}],[{\"text\":\"📝 View Changelog\",\"url\":\"$notes_url\"}]]}"
    else 
        kb="{\"inline_keyboard\":[[{\"text\":\"⬇️ Download Now\",\"url\":\"$dl_url\"}]]}"
    fi

    if [ -n "$TG_BANNER_PATH" ]; then
        method="sendPhoto"
        if [[ "$TG_BANNER_PATH" =~ ^http ]]; then
            photo_param="-F photo=$TG_BANNER_PATH"
        elif [ -f "$TG_BANNER_PATH" ]; then
            photo_param="-F photo=@$TG_BANNER_PATH"
        fi
    fi

    echo -e "\n\033[1;33mDEBUG: Contacting Telegram API...\033[0m"
    RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/$method" \
        $photo_param \
        -F "chat_id=$TG_CHAT_ID" \
        -F "parse_mode=Markdown" \
        -F "$([ "$method" == "sendPhoto" ] && echo "caption" || echo "text")=$(echo -e "$msg")" \
        -F "reply_markup=$kb")
    
    if [[ "$RESPONSE" == *"\"ok\":true"* ]]; then
        echo -e "\033[1;32m✅ Telegram Notification Sent Successfully!\033[0m"
    else
        echo -e "\033[1;31m❌ Telegram Error: $RESPONSE\033[0m"
    fi
}

# --- 4. WIZARD ---
run_setup() {
    [ -f "$WIZARD_STATE" ] && source "$WIZARD_STATE"
    step=${CURRENT_STEP:-1}
    while [ $step -le 9 ]; do
        clear; echo -e "\033[38;2;187;134;252mUNIVERSAL SETUP WIZARD\033[0m"
        case $step in
            1) echo "[1] Provider: 1) GD 2) SF"; read -p "Choice: " input; CLOUD_TYPE=${input:-1}; step=2 ;;
            2) if [ "$CLOUD_TYPE" == "1" ]; then PROVIDER="GD"; read -p "[2] Rclone Name: " input; REMOTE_URL="${input:-drive}:"; else PROVIDER="SF"; check_ssh_key || { step=1; continue; }; read -p "[2] SF User: " input; SF_USER=${input:-$USER}; fi; step=3 ;;
            3) if [ "$PROVIDER" == "GD" ]; then read -p "[3] Folder: " input; BASE_FOLDER=${input:-$DETECTED_BRAND}; else read -p "[3] SF Project: " input; SF_PROJ=${input:-${DETECTED_BRAND,,}}; REMOTE_URL="${SF_USER}@frs.sourceforge.net:/home/frs/project/${SF_PROJ}"; BASE_FOLDER=""; fi; step=4 ;;
            4) read -p "[4] Brand Name: " input; BRAND_ROM=${input:-$DETECTED_BRAND}; step=5 ;;
            5) read -p "[5] Maintainer Name: " input; MAINTAINER_VAL=${input:-$DEFAULT_MAINTAINER}; step=6 ;;
            6) read -p "[6] Source Path: " input; BUILD_PATH=${input:-$DETECTED_ROOT}; step=7 ;;
            7) read -p "[7] Enable Telegram? (y/n): " input; [[ "$input" =~ ^[Nn]$ ]] && TG_ENABLED="DISABLED" || TG_ENABLED="ENABLED"; step=8 ;;
            8) read -p "[8] TG Token: " input; BOT_TOKEN=${input:-$TG_TOKEN}; step=9 ;;
            9) read -p "[9] TG Chat ID: " input; CHAT_ID=${input:-$TG_CHAT_ID}; step=10 ;;
        esac
        echo "CURRENT_STEP=$step; PROVIDER=\"$PROVIDER\"; REMOTE_URL=\"$REMOTE_URL\"; BASE_FOLDER=\"$BASE_FOLDER\"; BRAND_ROM=\"$BRAND_ROM\"; MAINTAINER_VAL=\"$MAINTAINER_VAL\"; BUILD_PATH=\"$BUILD_PATH\"; TG_ENABLED=\"$TG_ENABLED\"; BOT_TOKEN=\"$BOT_TOKEN\"; CHAT_ID=\"$CHAT_ID\"; SF_PROJ=\"$SF_PROJ\"" > "$WIZARD_STATE"
    done
    cat << EOF > $CONF
PROVIDER_TYPE="$PROVIDER"
REMOTE_PATH="$REMOTE_URL"
CLOUD_BASE="$BASE_FOLDER"
DEFAULT_BRAND="$BRAND_ROM"
MAINTAINER_NAME="$MAINTAINER_VAL"
BASE_SEARCH_ROOT="$BUILD_PATH"
TG_TOKEN="$BOT_TOKEN"
TG_CHAT_ID="$CHAT_ID"
SF_PROJ="$SF_PROJ"
PROJECT_STATUS="ENABLED"
TG_NOTIFY="$TG_ENABLED"
TG_BANNER_PATH=""
TG_FOOTER=""
EOF
    rm -f "$WIZARD_STATE"; exec "$0"
}

[ ! -f "$CONF" ] && run_setup
source "$CONF"

# --- 5. MAIN MANAGER ---
while true; do
source "$CONF" 
[ -s "$LAST_SESSION" ] && source "$LAST_SESSION"

PATH_WARNING=""
[ ! -d "$BASE_SEARCH_ROOT" ] && PATH_WARNING="\033[1;31m[INVALID PATH]\033[0m"
STATUS_IND=$([ "$PROJECT_STATUS" == "ENABLED" ] && echo -e "\033[1;32mON\033[0m" || echo -e "\033[1;31mOFF\033[0m")
TG_IND=$([ "$TG_NOTIFY" == "ENABLED" ] && echo -e "\033[1;32mON\033[0m" || echo -e "\033[1;31mOFF\033[0m")

clear
echo -e "\033[1;38;5;141m🚀 ${SAVED_ROM:-$DEFAULT_BRAND} | \033[1;38;5;81mBuild Deployer\033[0m"
echo -e "\033[1;38;5;141m──────────────────────────────────────────────────\033[0m"
echo -e "1) \033[1;32m[UPLOAD]\033[0m New Build $PATH_WARNING"
echo -e "2) 📂 Manage Bookmarks"
echo -e "3) ⚙️ Quick Config"
echo -e "s) Toggle Project Status: $STATUS_IND"
echo -e "t) Toggle TG Notify: $TG_IND"
echo -e "r) Clear Custom Branding & Bookmarks"
echo -e "w) Factory Reset (Re-run Setup)"
echo -e "0) \033[1;31m❌ Exit\033[0m"
echo -e "\033[1;38;5;141m──────────────────────────────────────────────────\033[0m"
read -p " » Choice: " choice

    case $choice in
        0) read -p "Are you sure? (y/n): " confirm; [[ "$confirm" =~ ^[Yy]$ ]] && exit 0 ;;
        r) echo -e "\n\033[1;31m⚠️  WARNING: This will clear your bookmarks, banners, and footer text.\033[0m"
           read -p "Are you sure? (y/n): " confirm
           [[ "$confirm" =~ ^[Yy]$ ]] && { rm -rf "Upload"; exec "$0"; } ;;
        w) echo -e "\n\033[1;31m⚠️  WARNING: This wipes ALL settings and runs the setup wizard again.\033[0m"
           read -p "Are you sure? (y/n): " confirm
           [[ "$confirm" =~ ^[Yy]$ ]] && { rm -f "$CONF" "$WIZARD_STATE"; run_setup; } ;;
        s) [ "$PROJECT_STATUS" == "ENABLED" ] && val="DISABLED" || val="ENABLED"; sed -i "s|PROJECT_STATUS=.*|PROJECT_STATUS=\"$val\"|" $CONF; continue ;;
        t) [ "$TG_NOTIFY" == "ENABLED" ] && val="DISABLED" || val="ENABLED"; sed -i "s|TG_NOTIFY=.*|TG_NOTIFY=\"$val\"|" $CONF; continue ;;
        1)
            clear
            if [ ! -d "$BASE_SEARCH_ROOT" ]; then
                echo -e "\033[1;31m❌ ERROR: Source Path Not Found!\033[0m"; sleep 2; continue
            fi
            if [ -s "$LAST_SESSION" ]; then
                read -p "Reuse Last ROM ($SAVED_ROM)? (y/n): " reuse
                if [[ "$reuse" =~ ^[Yy]$ ]]; then PROJECT_DIR="$SAVED_ROM"; else
                    read -p "Project Name: " PROJECT_DIR; echo "SAVED_ROM=\"$PROJECT_DIR\"" > "$LAST_SESSION"
                fi
            else
                read -p "Project Name: " PROJECT_DIR; echo "SAVED_ROM=\"$PROJECT_DIR\"" > "$LAST_SESSION"
            fi
            
            AUTO_DEV=$(detect_active_device)
            read -p "Device [$AUTO_DEV]: " d_in; DEVICE_LOWER=$(echo "${d_in:-$AUTO_DEV}" | tr '[:upper:]' '[:lower:]')
            
            # --- DEEP SEARCH ---
            BUILD_DIR="$BASE_SEARCH_ROOT/out/target/product/$DEVICE_LOWER"
            if [ ! -d "$BUILD_DIR" ]; then
                FILES_FOUND=($(find "$BASE_SEARCH_ROOT/out" -type f \( -name "*.zip" -o -name "*.json" \) -iname "*$DEVICE_LOWER*" ! -name "*ota*" 2>/dev/null | xargs ls -t 2>/dev/null))
            else
                FILES_FOUND=($(find "$BUILD_DIR" -maxdepth 2 -type f \( -name "*.zip" -o -name "*.json" \) \( -iname "*official*" -o -iname "*unofficial*" -o -iname "*$DEVICE_LOWER*" \) ! -name "*ota*" 2>/dev/null | xargs ls -t 2>/dev/null))
            fi
            
            if [ ${#FILES_FOUND[@]} -gt 0 ]; then
                echo -e "\n📦 \033[1;37mFiles Found:\033[0m"
                for i in "${!FILES_FOUND[@]}"; do echo -e " $((i+1))) \033[1;34m$(basename "${FILES_FOUND[$i]}")\033[0m"; done
                read -p "Pick file [1] or 'b': " f_idx; [[ "$f_idx" == "b" ]] && continue
                f_idx=$(( ${f_idx:-1} - 1 ))
                BUILD_ZIP="${FILES_FOUND[$f_idx]}"
                
                # --- DESTINATION SELECTION ---
                IS_CUSTOM=false
                echo -e "\n☁️  \033[1;37mChoose Destination:\033[0m"
                echo "1) Default Path [${REMOTE_PATH}${CLOUD_BASE}]"
                echo "2) Select from Bookmarks"
                echo "3) Custom Path (Manual Input)"
                read -p "Choice: " path_choice
                case $path_choice in
                    2) i=1; while IFS= read -r line; do echo "$i) $line"; ((i++)); done < "$BOOKMARKS_FILE"
                       read -p "Pick # or 'b': " b_num; [[ "$b_num" == "b" ]] && continue
                       FINAL_DEST=$(sed -n "${b_num}p" "$BOOKMARKS_FILE") ;;
                    3) read -p "Custom Path: " FINAL_DEST; [ -z "$FINAL_DEST" ] && continue; IS_CUSTOM=true ;;
                    *) FINAL_DEST="${REMOTE_PATH}${CLOUD_BASE}" ;;
                esac

                FILENAME=$(basename "$BUILD_ZIP")
                FILE_SIZE=$(du -h "$BUILD_ZIP" | awk '{print $1}')
                MD5_SUM=$(md5sum "$BUILD_ZIP" | awk '{print $1}')
                ROM_VER=$(get_rom_version "$BUILD_ZIP")

                if [ "$PROVIDER_TYPE" == "SF" ]; then
                    DL_URL="https://sourceforge.net/projects/$SF_PROJ/files/$FILENAME/download"
                else
                    DL_URL="https://drive.google.com/drive/search?q=$FILENAME"
                fi

                clear
                echo -e "\033[1;32m📋 DEPLOYMENT SUMMARY\033[0m"
                echo -e "\033[1;38;5;141m──────────────────────────────────────────────────\033[0m"
                echo -e "📦 BUILD:      \033[1;37m$FILENAME\033[0m"
                echo -e "📊 SIZE:       \033[1;37m$FILE_SIZE\033[0m"
                echo -e "🔢 VERSION:    \033[1;37m$ROM_VER\033[0m"
                echo -e "📱 DEVICE:     \033[1;37m$DEVICE_LOWER\033[0m"
                echo -e "👤 MAINTAINER: \033[1;37m$MAINTAINER_NAME\033[0m"
                echo -e "🔗 LINK:       \033[1;36m$DL_URL\033[0m"
                echo -e "\033[1;38;5;141m──────────────────────────────────────────────────\033[0m"
                read -p "🚀 Start Upload? (y/n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    SUCCESS=false
                    if [ "$PROVIDER_TYPE" == "SF" ]; then
                         rsync -avP -z -e ssh --inplace "$BUILD_ZIP" "${FINAL_DEST}/" && SUCCESS=true
                    else
                         rclone copyto "$BUILD_ZIP" "$FINAL_DEST/$FILENAME" --progress && SUCCESS=true
                    fi
                    
                    if [ "$SUCCESS" = true ]; then
                        if [ "$IS_CUSTOM" = true ]; then
                            read -p "Save this custom path to bookmarks? (y/n): " s_bk
                            [[ "$s_bk" =~ ^[Yy]$ ]] && echo "$FINAL_DEST" >> "$BOOKMARKS_FILE"
                        fi
                        if [ "$TG_NOTIFY" == "ENABLED" ]; then
                            echo -e "\n\033[1;32m✅ Upload Successful!\033[0m"
                            read -p "Post to Telegram? (y/n): " tg_confirm
                            if [[ "$tg_confirm" =~ ^[Yy]$ ]]; then
                                [[ "$FILENAME" =~ [Oo][Ff][Ff][Ii][Cc][Ii][Aa][Ll] ]] && STATUS="✅ *Official*" || STATUS="🛠 *Unofficial*"
                                send_telegram "${PROJECT_DIR^^}" "${DEVICE_LOWER^^}" "$ROM_VER" "$STATUS" "$FILENAME" "$FILE_SIZE" "$MD5_SUM" "$DL_URL" "$(generate_auto_changelog)"
                                sleep 3
                            fi
                        fi
                    fi
                fi
            else echo -e "❌ No builds found."; sleep 2; fi ;;
        2) 
           while true; do
               clear; echo -e "\033[1;38;5;141m📂 Manage Bookmarks\033[0m"
               if [ ! -s "$BOOKMARKS_FILE" ]; then echo "   (No bookmarks saved)"; else
                   i=1; while IFS= read -r line; do echo "$i) $line"; ((i++)); done < "$BOOKMARKS_FILE"
               fi
               echo "a) Add New Bookmark"
               echo "d) Delete a Bookmark"
               echo "c) Clear All"
               echo "b) Back"
               read -p "» Choice: " bk_cmd; [[ "$bk_cmd" == "b" ]] && break
               if [[ "$bk_cmd" == "a" ]]; then read -p "Paste full path: " n_bk; [ -n "$n_bk" ] && echo "$n_bk" >> "$BOOKMARKS_FILE"
               elif [[ "$bk_cmd" == "d" ]]; then read -p "Bookmark # to delete: " d_idx; sed -i "${d_idx}d" "$BOOKMARKS_FILE"
               elif [[ "$bk_cmd" == "c" ]]; then read -p "Clear everything? (y/n): " cf; [[ "$cf" =~ ^[Yy]$ ]] && > "$BOOKMARKS_FILE"
               fi
           done ;;
        3) while true; do
               source "$CONF"; clear; echo -e "\033[1;38;5;141m⚙️ Quick Config\033[0m"
               echo "1) Bot Token     [Current: ${TG_TOKEN:0:5}***]"
               echo "2) Chat ID       [Current: $TG_CHAT_ID]"
               echo "3) Maintainer    [Current: $MAINTAINER_NAME]"
               echo "4) Banner Path   [Current: ${TG_BANNER_PATH:-Not Set}]"
               echo "5) Footer Text   [Current: ${TG_FOOTER:-Not Set}]"
               echo "6) Source Path   [Current: $BASE_SEARCH_ROOT]"
               echo "7) 📝 Manual Edit (Open in Editor)"
               echo "t) 🛠 Test Notify (With Debug Info)"
               echo "b) Back"
               read -p "Choice: " q_choice; [[ "$q_choice" == "b" ]] && break
               case $q_choice in
                    t) send_telegram "TEST" "DEVICE" "1.0" "✅" "test.zip" "1GB" "md5" "https://google.com" "FAILED"; echo -e "\nPress Enter to return..."; read ;;
                    7) ${EDITOR:-nano} "$CONF" ;;
                    1) read -p "Token: " t; [ -n "$t" ] && sed -i "s|^TG_TOKEN=.*|TG_TOKEN=\"$t\"|" $CONF ;;
                    2) read -p "ID: " i; [ -n "$i" ] && sed -i "s|^TG_CHAT_ID=.*|TG_CHAT_ID=\"$i\"|" $CONF ;;
                    3) read -p "Name: " n; [ -n "$n" ] && sed -i "s|^MAINTAINER_NAME=.*|MAINTAINER_NAME=\"$n\"|" $CONF ;;
                    4) read -p "Path: " b; [ -n "$b" ] && sed -i "s|^TG_BANNER_PATH=.*|TG_BANNER_PATH=\"$b\"|" $CONF ;;
                    5) read -p "Msg: " f; [ -n "$f" ] && sed -i "s|^TG_FOOTER=.*|TG_FOOTER=\"$f\"|" $CONF ;;
                    6) read -p "Path: " p; [ -n "$p" ] && sed -i "s|^BASE_SEARCH_ROOT=.*|BASE_SEARCH_ROOT=\"$p\"|" $CONF ;;
               esac
               echo -e "\033[1;32mUpdated.\033[0m"; sleep 1
           done ;;
    esac
done
