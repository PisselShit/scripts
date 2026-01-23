#!/bin/bash

CONF="config.conf"
BOOKMARKS_FILE="bookmarks.txt"
LAST_SESSION=".last_session"
WIZARD_STATE=".setup_state" 
touch "$BOOKMARKS_FILE" "$LAST_SESSION"

# --- 1. SMART DETECTION & AUTO-DISCOVERY ---
DETECTED_BRAND=$(basename "$(pwd)" | sed 's/[-_]//g' | tr '[:lower:]' '[:upper:]')
[ -d "build/make" ] && DETECTED_ROOT=$(pwd) || DETECTED_ROOT="$HOME/android"

detect_active_device() {
    local product_dir="$BASE_SEARCH_ROOT/out/target/product"
    if [ -d "$product_dir" ]; then
        local latest_dev=$(find "$product_dir" -maxdepth 2 -name "*.zip" -printf '%T+ %p\n' | sort -r | head -n 1 | awk '{print $2}' | cut -d/ -f6)
        echo "$latest_dev"
    fi
}

# --- 2. CHANGELOG & PASTE ENGINE ---
upload_to_paste() {
    local content="$1"
    local paste_url=$(curl -s -X POST https://spaceb.in/api/v1/documents/ \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"$content\", \"extension\": \"txt\"}" | grep -oP '(?<="key":")[^"]+')
    
    if [ -n "$paste_url" ]; then
        echo "https://spaceb.in/$paste_url"
    else
        echo "FAILED"
    fi
}

generate_auto_changelog() {
    echo -e "🔄 Gathering Git history..."
    if [ -d ".git" ]; then
        local logs=$(git log --oneline -n 15 --no-merges)
        upload_to_paste "$logs"
    else
        echo "FAILED"
    fi
}

# --- 3. SSH KEY HELPER ---
check_ssh_key() {
    clear
    echo -e "\n\033[38;2;139;233;253m🔐 Checking for SourceForge SSH Keys...\033[0m"
    if [ -f ~/.ssh/id_ed25519.pub ]; then
        KEY_PATH="$HOME/.ssh/id_ed25519.pub"
    elif [ -f ~/.ssh/id_rsa.pub ]; then
        KEY_PATH="$HOME/.ssh/id_rsa.pub"
    else
        echo -e "❌ No SSH key found."
        echo -e "y) Generate New Key\nn) Skip\nb) Back"
        read -p "Choice: " gen_key
        [[ "$gen_key" == "b" ]] && return 1
        if [[ "$gen_key" =~ ^[Yy]$ ]]; then
            ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
            KEY_PATH="$HOME/.ssh/id_ed25519.pub"
        else
            return 1
        fi
    fi
    command -v xclip >/dev/null && { cat "$KEY_PATH" | xclip -selection clipboard; CLIP_MSG="📋 Key AUTO-COPIED!"; }
    echo -e "──────────────────────────────────────────────────"
    echo -e "\033[1;38;2;3;218;198m🚀 HOW TO ENABLE PASSWORDLESS UPLOADS:\033[0m"
    echo -e "──────────────────────────────────────────────────"
    echo -e "\033[38;2;255;184;108m"
    cat "$KEY_PATH"
    echo -e "\033[0m──────────────────────────────────────────────────"
    echo -e "y) Continue\nb) Back"
    read -p "Choice: " ssh_back
    [[ "$ssh_back" == "b" ]] && return 1
    return 0
}

# --- 4. VERTICAL NAVIGATIONAL WIZARD ---
run_setup() {
    [ -f "$WIZARD_STATE" ] && source "$WIZARD_STATE"
    step=${CURRENT_STEP:-1}
    while [ $step -le 7 ]; do
        clear
        echo -e "\033[38;2;187;134;252m             UNIVERSAL SETUP WIZARD\033[0m"
        echo -e "──────────────────────────────────────────────────"
        case $step in
            1)
                echo -e "\n[1] Select Provider:"
                echo "1) Google Drive"
                echo "2) SourceForge"
                read -p "Choice [${CLOUD_TYPE:-1}]: " input
                [ "$input" == "b" ] && { rm -f "$WIZARD_STATE"; exec "$0"; }
                CLOUD_TYPE=${input:-${CLOUD_TYPE:-1}}; step=2 ;;
            2)
                if [ "$CLOUD_TYPE" == "1" ]; then
                    PROVIDER="GD"
                    echo -e "\n[2] Rclone Config Name:"
                    read -p "Name [${REMOTE_NAME:-drive}] (or 'b'): " input
                    [ "$input" == "b" ] && { step=1; continue; }
                    REMOTE_NAME=${input:-${REMOTE_NAME:-drive}}; REMOTE_URL="${REMOTE_NAME//:/}:"
                else
                    PROVIDER="SF"
                    if ! check_ssh_key; then step=1; continue; fi
                    echo -e "\n[2] SF Username:"
                    read -p "User [${SF_USER:-$USER}] (or 'b'): " input
                    [ "$input" == "b" ] && { step=1; continue; }
                    SF_USER=${input:-${SF_USER:-$USER}}
                fi
                step=3 ;;
            3)
                if [ "$PROVIDER" == "GD" ]; then
                    echo -e "\n[3] Cloud Folder:"
                    read -p "Folder [${BASE_FOLDER:-$DETECTED_BRAND}] (or 'b'): " input
                    [ "$input" == "b" ] && { step=2; continue; }
                    BASE_FOLDER=${input:-${BASE_FOLDER:-$DETECTED_BRAND}}
                else
                    echo -e "\n[3] SF Project Name:"
                    read -p "Project [${SF_PROJ:-${DETECTED_BRAND,,}}] (or 'b'): " input
                    [ "$input" == "b" ] && { step=2; continue; }
                    SF_PROJ=${input:-${SF_PROJ:-${DETECTED_BRAND,,}}}
                    REMOTE_URL="${SF_USER}@frs.sourceforge.net:/home/frs/project/${SF_PROJ}"; BASE_FOLDER=""
                fi
                step=4 ;;
            4)
                echo -e "\n[4] Identity Setup:"
                read -p "Brand Name [${BRAND_ROM:-$DETECTED_BRAND}] (or 'b'): " input
                [ "$input" == "b" ] && { step=3; continue; }
                BRAND_ROM=${input:-${BRAND_ROM:-$DETECTED_BRAND}}; step=5 ;;
            5)
                echo -e "\n[5] Source Path:"
                read -p "Path [${BUILD_PATH:-$DETECTED_ROOT}] (or 'b'): " input
                [ "$input" == "b" ] && { step=4; continue; }
                BUILD_PATH=${input:-${BUILD_PATH:-$DETECTED_ROOT}}; step=6 ;;
            6)
                echo -e "\n[6] Telegram Bot Token:"
                read -p "Token [${BOT_TOKEN:-None}] (or 'b'): " input
                [ "$input" == "b" ] && { step=5; continue; }
                BOT_TOKEN=${input:-${BOT_TOKEN:-$TG_TOKEN}}; step=7 ;;
            7)
                echo -e "\n[7] Telegram Chat ID:"
                read -p "Chat ID [${CHAT_ID:-None}] (or 'b'): " input
                [ "$input" == "b" ] && { step=6; continue; }
                CHAT_ID=${input:-${CHAT_ID:-$TG_CHAT_ID}}; step=8 ;;
        esac
        echo "CURRENT_STEP=$step; CLOUD_TYPE=\"$CLOUD_TYPE\"; REMOTE_NAME=\"$REMOTE_NAME\"; SF_USER=\"$SF_USER\"; SF_PROJ=\"$SF_PROJ\"; BASE_FOLDER=\"$BASE_FOLDER\"; BRAND_ROM=\"$BRAND_ROM\"; BUILD_PATH=\"$BUILD_PATH\"; BOT_TOKEN=\"$BOT_TOKEN\"; CHAT_ID=\"$CHAT_ID\"" > "$WIZARD_STATE"
    done
    cat << EOF > $CONF
PROVIDER_TYPE="$PROVIDER"
REMOTE_PATH="$REMOTE_URL"
CLOUD_BASE="$BASE_FOLDER"
DEFAULT_BRAND="$BRAND_ROM"
BASE_SEARCH_ROOT="$BUILD_PATH"
TG_TOKEN="$BOT_TOKEN"
TG_CHAT_ID="$CHAT_ID"
EOF
    rm -f "$WIZARD_STATE"; exec "$0"
}

# --- 5. TELEGRAM ENGINE ---
send_telegram() {
    local text="$1"
    local dl_url="$2"
    local notes_url="$3"
    
    local kb
    if [ -n "$notes_url" ] && [ "$notes_url" != "FAILED" ]; then
        kb="{\"inline_keyboard\":[[{\"text\":\"⬇️ Download Now\",\"url\":\"$dl_url\"}],[{\"text\":\"📝 View Changelog\",\"url\":\"$notes_url\"}]]}"
    else
        kb="{\"inline_keyboard\":[[{\"text\":\"⬇️ Download Now\",\"url\":\"$dl_url\"}]]}"
    fi

    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        --data-urlencode "chat_id=$TG_CHAT_ID" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "text=$text" \
        --data-urlencode "reply_markup=$kb" > /dev/null
}

[ ! -f "$CONF" ] && run_setup
source "$CONF"

# --- 6. MAIN MANAGER ---
while true; do
[ -s "$LAST_SESSION" ] && source "$LAST_SESSION"
DYNAMIC_TITLE="${SAVED_ROM:-${DEFAULT_BRAND:-Universal}}"

clear
echo -e "\033[38;2;187;134;252m🚀 $DYNAMIC_TITLE | Build Deployer\033[0m"
echo -e "──────────────────────────────────────────────────"
echo -e "\033[1;38;2;139;233;253m1) [UPLOAD] New Build\n2) 📂 Manage Bookmarks\n3) ⚙️ Quick Config\n4) ❌ Exit\033[0m"
echo -e "──────────────────────────────────────────────────"
[ -n "$SAVED_ROM" ] && echo -e "\033[38;2;255;184;108m🕒 Last ROM:\033[0m $SAVED_ROM\n\033[38;2;3;218;198m📍 Last Path:\033[0m ${LAST_PATH:-Default}"
echo -e "──────────────────────────────────────────────────"
read -p "» Select action: " choice

    case $choice in
        1)
            clear
            echo -e "\033[38;2;187;134;252m"
            echo "  _    _ _____  _      ____          _____ _____ _   _  _____ "
            echo " | |  | |  __ \| |    / __ \   /\   |  __ \_   _| \ | |/ ____|"
            echo " | |  | | |__) | |   | |  | | /  \  | |  | || | |  \| | |  __ "
            echo " | |  | |  ___/| |   | |  | |/ /\ \ | |  | || | | . \ | | |_ |"
            echo " | |__| | |    | |___| |__| / ____ \| |__| || |_| |\  | |__| |"
            echo "  \____/|_|    |______\____/_/    \_\_____/_____|_| \_|\_____|"
            echo -e "\033[0m"

            [ -s "$LAST_SESSION" ] && echo -e "Reuse Last ROM ($SAVED_ROM)?\ny) Yes\nn) No\nb) Back" && read -p "Choice: " reuse
            [[ "$reuse" == "b" ]] && continue
            if [[ "$reuse" =~ ^[Yy]$ ]]; then PROJECT_DIR="$SAVED_ROM"; else
                read -p "Project Name [b for back]: " PROJECT_DIR
                [[ "$PROJECT_DIR" == "b" ]] && continue
                echo "SAVED_ROM=\"$PROJECT_DIR\"" > "$LAST_SESSION"
            fi
            
            AUTO_DEV=$(detect_active_device)
            if [ -n "$AUTO_DEV" ]; then
                echo -e "Device Name:\n[$AUTO_DEV] (Enter to use detected)\nb) Back"
                read -p "Device: " DEVICE_INPUT
                [[ "$DEVICE_INPUT" == "b" ]] && continue
                DEVICE_INPUT=${DEVICE_INPUT:-$AUTO_DEV}
            else
                read -p "Device Name [b for back]: " DEVICE_INPUT
                [[ "$DEVICE_INPUT" == "b" ]] && continue
            fi
            DEVICE_LOWER=$(echo "$DEVICE_INPUT" | tr '[:upper:]' '[:lower:]')
            DEVICE_CAPITALIZED="$(tr '[:lower:]' '[:upper:]' <<< ${DEVICE_LOWER:0:1})${DEVICE_LOWER:1}"

            echo -ne "\033[38;2;139;233;253m🔍 Searching for builds... \033[0m"
            spinner=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
            TARGET_SEARCH_DIR="$BASE_SEARCH_ROOT/out/target/product/$DEVICE_LOWER"
            ( find "$TARGET_SEARCH_DIR" -maxdepth 2 -type f -name "*.zip" \( -iname "*official*" -o -iname "*unofficial*" \) ! -name "*ota*" ! -name "*target_files*" ! -name "*symbols*" 2>/dev/null | xargs ls -t 2>/dev/null | head -n 1 > .tmp_zip ) &
            SEARCH_PID=$!
            while kill -0 $SEARCH_PID 2>/dev/null; do for i in "${spinner[@]}"; do echo -ne "\b$i"; sleep 0.1; done; done
            BUILD_ZIP=$(cat .tmp_zip); rm .tmp_zip; echo -e "\b Done!"

            if [ -f "$BUILD_ZIP" ]; then
                FILENAME=$(basename "$BUILD_ZIP"); ROM_VERSION=$(echo "$FILENAME" | grep -oP '(?<=[vV])\d+(\.\d+)?|\b\d+\.\d+\b|\b\d\b' | head -n 1)
                FILE_SIZE_HUMAN=$(du -h "$BUILD_ZIP" | awk '{print $1}'); MD5_SUM=$(md5sum "$BUILD_ZIP" | awk '{print $1}')
                [[ "$FILENAME" =~ [Oo][Ff][Ff][Ii][Cc][Ii][Aa][Ll] && ! "$FILENAME" =~ [Uu][Nn][Oo][Ff][Ff][Ii][Cc][Ii][Aa][Ll] ]] && BUILD_STATUS="✅ *Official*" || BUILD_STATUS="🛠 *Unofficial*"

                echo -e "\n\033[38;2;3;218;198m🔎 Found:\033[0m $FILENAME\n🔢 Version: $ROM_VERSION | 🛡 MD5: ${MD5_SUM:0:8}..."
                
                CLEAN_BASE=$(echo "$CLOUD_BASE" | sed 's|^/||; s|/$||'); REMOTE_NAME=$(echo "$REMOTE_PATH" | cut -d: -f1)
                FINAL_DEST_PATH=$(echo "${REMOTE_NAME}:${CLEAN_BASE}" | sed 's|//|/|g')

                echo -e "\n\033[38;2;139;233;253m📂 Destination:\033[0m"
                echo -e "1) Default Root: $FINAL_DEST_PATH"
                declare -A bookmarks; count=2
                while IFS= read -r line; do [ -n "$line" ] && { echo -e "$count) Bookmark: $line"; bookmarks[$count]=$line; ((count++)); }; done < "$BOOKMARKS_FILE"
                echo -e "$count) Enter Custom Subfolder"
                echo -e "b) Back to Main Menu"

                read -p "Select [1-$count/b]: " path_choice
                [[ "$path_choice" == "b" ]] && continue
                [ "$path_choice" == "1" ] && FINAL_DEST="$FINAL_DEST_PATH" || {
                    [ "$path_choice" == "$count" ] && { read -p "Sub-path [b for back]: " sub_p; [[ "$sub_p" == "b" ]] && continue; FINAL_DEST="${FINAL_DEST_PATH}/${sub_p}"; read -p "Save? (y/n): " s && [[ "$s" =~ ^[Yy]$ ]] && echo "$FINAL_DEST" >> "$BOOKMARKS_FILE"; } || FINAL_DEST="${bookmarks[$path_choice]}"
                }
                
                echo "SAVED_ROM=\"$PROJECT_DIR\"" > "$LAST_SESSION"; echo "LAST_PATH=\"$FINAL_DEST\"" >> "$LAST_SESSION"
                [ -n "$LAST_CL_LINK" ] && echo "LAST_CL_LINK=\"$LAST_CL_LINK\"" >> "$LAST_SESSION"
                
                echo -e "Confirm Upload?\ny) Yes\nn) No\nb) Back" && read -p "Choice: " confirm_final
                [[ "$confirm_final" == "b" ]] && continue
                
                if [[ "$confirm_final" =~ ^[Yy]$ ]]; then
                    UPLOAD_SUCCESS=false; ATTEMPT=1; MAX_ATTEMPTS=3
                    while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$UPLOAD_SUCCESS" = false ]; do
                        if [ "$PROVIDER_TYPE" == "SF" ]; then
                            SF_PATH=$(echo "$FINAL_DEST" | cut -d: -f2); SF_HOST=$(echo "$FINAL_DEST" | cut -d: -f1)
                            ssh "$SF_HOST" "mkdir -p $SF_PATH"
                            rsync -avP -z -e ssh --inplace --append-verify "$BUILD_ZIP" "${FINAL_DEST}/" && UPLOAD_SUCCESS=true
                        else
                            rclone copyto "$BUILD_ZIP" "$FINAL_DEST/$FILENAME" --progress --stats-one-line --transfers 4 --checkers 8 --drive-chunk-size 128M --buffer-size 64M && UPLOAD_SUCCESS=true
                        fi
                        [ "$UPLOAD_SUCCESS" = false ] && sleep 15 && ((ATTEMPT++))
                    done

                    if [ "$UPLOAD_SUCCESS" = true ]; then
                        if [ "$PROVIDER_TYPE" == "SF" ]; then
                            PROJ_NAME=$(echo "$REMOTE_PATH" | rev | cut -d/ -f1 | rev)
                            DOWNLOAD_LINK="https://sourceforge.net/projects/${PROJ_NAME}/files/${FILENAME}/download"
                        else
                            FILE_ID=$(rclone lsf "$FINAL_DEST" --include "$FILENAME" --format "i")
                            DOWNLOAD_LINK="https://drive.google.com/uc?export=download&id=$FILE_ID"
                        fi

                        echo -e "\nAdd Changelog?"
                        [ -n "$LAST_CL_LINK" ] && echo "0) 💾 Reuse Last: $LAST_CL_LINK"
                        echo "1) 📝 Auto-Generate (Git Logs)"
                        echo "2) ✍️ Write Custom Notes"
                        echo "3) 🔗 Paste New Link"
                        echo "4) ❌ Skip"
                        read -p "Choice [0-4]: " changelog_choice
                        
                        CHANGELOG_URL=""
                        case $changelog_choice in
                            0) CHANGELOG_URL="$LAST_CL_LINK" ;;
                            1) CHANGELOG_URL=$(generate_auto_changelog) ;;
                            2) read -p "Notes: " cn; CHANGELOG_URL=$(upload_to_paste "$cn") ;;
                            3) read -p "Link: " CHANGELOG_URL ;;
                        esac
                        
                        [ -n "$CHANGELOG_URL" ] && [ "$CHANGELOG_URL" != "FAILED" ] && { 
                            sed -i '/LAST_CL_LINK=/d' "$LAST_SESSION"
                            echo "LAST_CL_LINK=\"$CHANGELOG_URL\"" >> "$LAST_SESSION"
                        }

                        echo -e "Broadcast to Telegram?\ny) Yes\nn) No\nb) Back" && read -p "Choice: " tg_confirm
                        [[ "$tg_confirm" == "b" ]] && continue
                        if [[ "$tg_confirm" =~ ^[Yy]$ ]]; then
                            BANNER_NAME=$(echo "$PROJECT_DIR" | tr '[:lower:]' '[:upper:]')
                            MSG=$(printf "━━━━━ $BANNER_NAME ━━━━━\n🚀 *Build Ready!*\n\n🔢 *Version:* $ROM_VERSION\n📱 *Device:* $DEVICE_CAPITALIZED\n🛡 *Status:* $BUILD_STATUS\n📦 *Filename:* \`$FILENAME\`\n📊 *Size:* $FILE_SIZE_HUMAN\n🔐 *MD5:* \`$MD5_SUM\`\n━━━━━━━━━━━━━━━━━━━━")
                            send_telegram "$MSG" "$DOWNLOAD_LINK" "$CHANGELOG_URL"
                        fi
                    fi
                fi
            else echo -e "❌ No builds found."; sleep 2; fi ;;
        2) 
           while true; do
               clear; echo -e "\033[38;2;187;134;252m📂 Bookmark Manager\033[0m\n────────────────────────────"
               declare -A bks; i=1
               while IFS= read -r line; do [ -n "$line" ] && { echo -e "$i) $line"; bks[$i]=$line; ((i++)); }; done < "$BOOKMARKS_FILE"
               echo -e "────────────────────────────"
               read -p "Action ([Line #], s [Line #], b): " bk_cmd
               [[ "$bk_cmd" == "b" ]] && break
               if [[ "$bk_cmd" =~ ^s\ [0-9]+$ ]]; then
                   idx=$(echo $bk_cmd | awk '{print $2}')
                   new_root=$(echo "${bks[$idx]}" | cut -d: -f2-)
                   sed -i "s|CLOUD_BASE=.*|CLOUD_BASE=\"$new_root\"|" $CONF; source $CONF
                   echo -e "✅ Default updated!"; sleep 1
               elif [[ "$bk_cmd" =~ ^[0-9]+$ ]]; then
                   sed -i "${bk_cmd}d" "$BOOKMARKS_FILE"
               fi
           done ;;
        3) 
           while true; do
               clear; echo -e "\033[38;2;187;134;252m⚙️ Quick Config\033[0m"
               echo -e "1) 🤖 Bot Token\n2) 💬 Chat ID\n3) 📂 Source Path\n4) 🏷 Brand Name\n5) 📡 Test Telegram Connection\n6) 🔄 RESET WIZARD\n7) ⬅️ Back"
               read -p "Choice [1-7]: " q_choice; case $q_choice in
                    7|b) break ;; 
                    5) send_telegram "🚀 *Script Test:* Successful!" "https://github.com" ""; sleep 1 ;;
                    6) rm "$CONF"; run_setup ;;
                    1) read -p "Token: " t; sed -i "s|TG_TOKEN=.*|TG_TOKEN=\"$t\"|" $CONF ;;
                    2) read -p "ID: " i; sed -i "s|TG_CHAT_ID=.*|TG_CHAT_ID=\"$i\"|" $CONF ;;
                    3) read -p "Path: " p; sed -i "s|BASE_SEARCH_ROOT=.*|BASE_SEARCH_ROOT=\"$p\"|" $CONF ;;
                    4) read -p "Brand: " b; sed -i "s|DEFAULT_BRAND=.*|DEFAULT_BRAND=\"$b\"|" $CONF ;;
               esac; source "$CONF"
           done ;;
        4) exit 0 ;;
    esac
done
