#!/bin/bash

# --- CORE FILES & DATABASE ---
CONF="config.conf"
PROF_DIR="profiles"
mkdir -p "$PROF_DIR"
BOOKMARKS_FILE="bookmarks.txt"
HEIST_DB="heist.list"
CHERRY_DB="cherry-pick.list"
REVERT_DB="reverts.list"
LAST_SESSION=".last_session"
LAST_NAME_DB=".last_name"

# --- HEX COLOR ENGINE ---
hex_fg() { echo -ne "\033[38;2;$1;$2;$3m"; }
NC='\033[0m'; C_PRIME=$(hex_fg 187 134 252); C_GOSSIP=$(hex_fg 139 233 253)
C_ACCENT=$(hex_fg 3 218 198); C_WARN=$(hex_fg 255 184 108)
C_DANGER=$(hex_fg 255 85 85); C_GREY=$(hex_fg 120 120 120)

# --- AUTO-SAVE LOGIC ---
auto_save_profile() {
    source "$CONF" 2>/dev/null
    if [ -n "$ROM_NAME" ]; then
        CLEAN_NAME=$(echo "$ROM_NAME" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
        cp "$CONF" "$PROF_DIR/${CLEAN_NAME}_autosave.conf"
    fi
}

# --- 1. SETUP & PROJECT ENGINES ---
test_telegram() {
    source "$CONF" 2>/dev/null
    echo -e "\n  ${C_GOSSIP}📱 Testing Telegram Notification...${NC}"
    if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
        echo -e "  ${C_DANGER}✖ Error: Token or Chat ID is missing in config!${NC}"
        return
    fi
    RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        --data-urlencode "chat_id=$TG_CHAT_ID" \
        --data-urlencode "text=🔔 Test notification from your Build Script!")
    
    if [[ "$RESPONSE" == *"\"ok\":true"* ]]; then
        echo -e "  ${C_ACCENT}✔ Success! Check your Telegram.${NC}"
    else
        echo -e "  ${C_DANGER}✖ Failed!${NC}"
        echo -e "  ${C_GREY}Details: $RESPONSE${NC}"
    fi
}

manage_profiles() {
    while true; do
        show_banner
        echo -e "  ${C_GOSSIP}[ PROJECT SWITCHER ]${NC}\n"
        echo -e "  ${C_ACCENT}1)${NC} Load Profile"
        echo -e "  ${C_ACCENT}2)${NC} Save Current as New Profile"
        echo -e "  ${C_DANGER}3)${NC} Delete Profile"
        echo -e "  ${C_WARN}b)${NC} Back\n"
        read -p "  Selection » " p_choice

        case $p_choice in
            1)
                local i=1; declare -A profs
                for f in "$PROF_DIR"/*.conf; do
                    [ -e "$f" ] || continue
                    name=$(basename "$f" .conf)
                    profs[$i]=$f; echo -e "  $i) $name"; ((i++))
                done
                read -p "  Load #: " ln; [ -f "${profs[$ln]}" ] && cp "${profs[$ln]}" "$CONF" && source "$CONF" && echo -e "  ${C_ACCENT}✔ Profile Loaded!${NC}" && sleep 1
                ;;
            2)
                read -p "  New Profile Name: " pname
                cp "$CONF" "$PROF_DIR/$pname.conf" && echo -e "  ${C_ACCENT}✔ Profile Saved!${NC}" && sleep 1
                ;;
            3)
                local i=1; declare -A dprofs
                for f in "$PROF_DIR"/*.conf; do
                    [ -e "$f" ] || continue
                    name=$(basename "$f" .conf)
                    dprofs[$i]=$f; echo -e "  $i) $name"; ((i++))
                done
                read -p "  Delete #: " dn; [ -f "${dprofs[$dn]}" ] && rm "${dprofs[$dn]}" && echo -e "  ${C_DANGER}✖ Profile Deleted.${NC}" && sleep 1
                ;;
            b) break ;;
        esac
    done
}

run_setup_wizard() {
    show_banner
    echo -e "  ${C_GOSSIP}[ SYSTEM SETUP ]${NC}"
    echo -e "  "
    echo -e "  ${C_ACCENT}1)${NC} Soft Reset (Update Specific Keys)"
    echo -e "  ${C_ACCENT}p)${NC} Project Switcher (Profiles)"
    echo -e "  ${C_ACCENT}t)${NC} Test Telegram Connection"
    echo -e "  ${C_DANGER}2)${NC} Factory Reset (Wipe ALL Lists/Configs)"
    echo -e "  ${C_WARN}b)${NC} Back"
    echo -e "  "
    read -p "  Selection » " reset_choice

    if [[ "$reset_choice" == "1" ]]; then
        soft_reset_menu; return
    elif [[ "$reset_choice" == "p" ]]; then
        manage_profiles; return
    elif [[ "$reset_choice" == "t" ]]; then
        test_telegram; read -p "  Done..."; return
    elif [[ "$reset_choice" == "2" ]]; then
        read -p "  ⚠️  WIPE EVERYTHING? (y/n): " confirm_wipe
        if [[ "$confirm_wipe" =~ ^[Yy]$ ]]; then
            rm -f "$CONF" "$BOOKMARKS_FILE" "$HEIST_DB" "$CHERRY_DB" "$REVERT_DB" "$LAST_SESSION" "$LAST_NAME_DB"
            echo -e "  ${C_DANGER}✖ System Purged.${NC}"
            sleep 1
        else
            return
        fi
    elif [[ "$reset_choice" == "b" ]]; then
        return
    fi

    echo -e "\n  ${C_PRIME}🚀 INITIALIZING...${NC}"
    read -p "  🏷️  ROM Name: " R_NAME
    read -p "  🔢 ROM Version: " R_VER
    
    echo -e "\n  ${C_GREY}BUILD STATUS:${NC}"
    echo -e "  1) Official  2) Testing  3) Unofficial"
    read -p "  Selection » " s_choice
    case $s_choice in 1) R_STAT="Official" ;; 2) R_STAT="Testing" ;; 3) R_STAT="Unofficial" ;; *) R_STAT="Official" ;; esac

    read -p "  🤖 TG Token: " T_TOK
    read -p "  🆔 TG Chat ID: " T_ID
    
    CUR_DIR=$(pwd)
    read -p "  📁 Root Path ($CUR_DIR): " B_ROOT
    B_ROOT=${B_ROOT:-$CUR_DIR}
    
    echo -e "\n  ${C_GOSSIP}[ UPLOAD PROVIDER ]${NC}"
    echo -e "  ${C_ACCENT}1)${NC} SourceForge"
    echo -e "  ${C_ACCENT}2)${NC} Google Drive"
    read -p "  Selection » " p_choice
    
    if [[ "$p_choice" == "1" ]]; then
        P_TYPE="SF"
        read -p "  🔗 SF Path: " R_PATH
    else
        P_TYPE="RCLONE"
        read -p "  📡 Rclone Remote Name: " R_PATH
        R_PATH="${R_PATH%:}"
    fi
    read -p "  📂 Cloud Subfolder: " C_BASE

    cat <<EOF > "$CONF"
ROM_NAME='$R_NAME'
ROM_VERSION='$R_VER'
ROM_STATUS='$R_STAT'
TG_TOKEN='$T_TOK'
TG_CHAT_ID='$T_ID'
BASE_SEARCH_ROOT='$B_ROOT'
PROVIDER_TYPE='$P_TYPE'
REMOTE_PATH='$R_PATH'
CLOUD_BASE='$C_BASE'
EOF
    source "$CONF"
    auto_save_profile
    read -p "  Setup Finished..."
}

soft_reset_menu() {
    while true; do
        source "$CONF" 2>/dev/null
        show_banner
        echo -e "  ${C_GOSSIP}[ SOFT RESET - SELECT KEY ]${NC}\n"
        echo -e "  ${C_ACCENT}1)${NC} ROM Name/Version/Status (${ROM_NAME:-ROM} v${ROM_VERSION:-0} [${ROM_STATUS:-Official}])"
        echo -e "  ${C_ACCENT}2)${NC} Telegram Credentials"
        echo -e "  ${C_ACCENT}3)${NC} Provider Toggle (${PROVIDER_TYPE:-RCLONE})"
        echo -e "  ${C_ACCENT}4)${NC} Remote Path & Subfolder"
        echo -e "  ${C_WARN}b)${NC} Back\n"
        read -p "  Update Choice » " sc
        
        case $sc in
            1) 
                read -p " New Name: " val; [ -n "$val" ] && sed -i "s/ROM_NAME=.*/ROM_NAME='$val'/" "$CONF"
                read -p " New Ver: " val; [ -n "$val" ] && sed -i "s/ROM_VERSION=.*/ROM_VERSION='$val'/" "$CONF"
                echo -e " 1) Official 2) Testing 3) Unofficial"
                read -p " New Status » " s_val
                case $s_val in 1) ns="Official" ;; 2) ns="Testing" ;; 3) ns="Unofficial" ;; *) ns="Official" ;; esac
                sed -i "s/ROM_STATUS=.*/ROM_STATUS='$ns'/" "$CONF"
                ;;
            2) 
                read -p " New Token: " val; [ -n "$val" ] && sed -i "s/TG_TOKEN=.*/TG_TOKEN='$val'/" "$CONF"
                read -p " New ID: " val; [ -n "$val" ] && sed -i "s/TG_CHAT_ID=.*/TG_CHAT_ID='$val'/" "$CONF"
                ;;
            3) 
                if [[ "$PROVIDER_TYPE" == "SF" ]]; then
                    sed -i "s/PROVIDER_TYPE=.*/PROVIDER_TYPE='RCLONE'/" "$CONF"
                else
                    sed -i "s/PROVIDER_TYPE=.*/PROVIDER_TYPE='SF'/" "$CONF"
                fi
                source "$CONF"
                ;;
            4) 
                read -p " New Remote/Path: " val; [ -n "$val" ] && sed -i "s/REMOTE_PATH=.*/REMOTE_PATH='${val%:}'/" "$CONF"
                read -p " New Subfolder: " val; [ -n "$val" ] && sed -i "s/CLOUD_BASE=.*/CLOUD_BASE='$val'/" "$CONF"
                ;;
            b) break ;;
        esac
        auto_save_profile
    done
}

update_version_only() {
    source "$CONF"
    show_banner
    echo -e "  ${C_GOSSIP}[ QUICK UPDATE ]${NC}"
    echo -e "  "
    echo -e "  ${C_ACCENT}1)${NC} Change Version ($ROM_VERSION)"
    echo -e "  ${C_ACCENT}2)${NC} Toggle Provider ($PROVIDER_TYPE)"
    echo -e "  ${C_WARN}b)${NC} Back"
    echo -e "  "
    read -p "  Selection » " q_choice
    
    if [[ "$q_choice" == "1" ]]; then
        read -p "  New Version: " NEW_VER
        [ -n "$NEW_VER" ] && sed -i "s/ROM_VERSION=.*/ROM_VERSION='$NEW_VER'/" "$CONF"
    elif [[ "$q_choice" == "2" ]]; then
        NEW_P=$([[ "$PROVIDER_TYPE" == "SF" ]] && echo "RCLONE" || echo "SF")
        sed -i "s/PROVIDER_TYPE=.*/PROVIDER_TYPE='$NEW_P'/" "$CONF"
    fi
    source "$CONF"
    auto_save_profile
    read -p "  Finished..."
}

# --- 2. UI UTILITIES ---
show_banner() {
    clear
    source "$CONF" 2>/dev/null
    echo -e "${C_GREY}╭──────────────────────────────────────────╮${NC}"
    echo -e "${C_GREY}│${NC}           ◉ ${ROM_NAME:-ROM} v${ROM_VERSION:-0}           ${C_GREY}│${NC}"
    echo -e "${C_GREY}╰──────────────────────────────────────────╯${NC}"
}

manage_list() {
    local db=$1; local title=$2
    while true; do
        show_banner
        echo -e "  ${C_GOSSIP}[ $title ]${NC}\n"
        local i=1
        while IFS= read -r l; do
            [[ "$l" =~ ^#.* ]] || [ -z "$l" ] && continue
            echo -e "  ${C_ACCENT}$i)${NC} $l"; ((i++))
        done < "$db"
        echo -e "\n  ${C_GREY}ACTIONS:${NC}"
        echo -e "  ${C_ACCENT}a)${NC} Add Entry"
        echo -e "  ${C_DANGER}d)${NC} Delete Entry"
        echo -e "  ${C_PRIME}v)${NC} Verify Paths"
        echo -e "  ${C_WARN}b)${NC} Back"
        echo -e "  "
        read -p "  Selection » " opt
        case $opt in
            a) read -p "  Data: " d; echo "$d" >> "$db" ;;
            d) read -p "  Line #: " n; sed -i "${n}d" "$db" ;;
            v) 
                echo -e "\n  ${C_WARN}🔎 Validating...${NC}"
                while IFS= read -r path; do
                    [ -z "$path" ] && continue
                    if [[ "$path" == *":"* ]]; then
                        rclone lsd "$path" --max-depth 1 &>/dev/null && echo -e "  ${C_ACCENT}✔${NC} $path" || echo -e "  ${C_DANGER}✖${NC} $path"
                    else
                        [ -d "$path" ] && echo -e "  ${C_ACCENT}✔${NC} $path" || echo -e "  ${C_DANGER}✖${NC} $path"
                    fi
                done < "$db"
                read -p "  Finished..." ;;
            b) break ;;
        esac
    done
}

# --- 3. EXECUTION ENGINES ---
run_heist() {
    show_banner
    echo -e "  ${C_GOSSIP}🗂️  REPO HEIST...${NC}\n"
    while IFS='|' read -r URL REL BRANCH; do
        [[ "$URL" =~ ^#.* ]] || [ -z "$URL" ] && continue
        T_FOLDER=$(basename "$REL"); T_PARENT=$(dirname "$REL")
        if [ -d "$T_PARENT" ]; then
            FOREIGN=$(find "$T_PARENT" -maxdepth 1 -type d -not -name "$T_FOLDER" -not -path "$T_PARENT")
            if [ -n "$FOREIGN" ]; then
                echo -e "  ${C_WARN}⚠️  Conflict in $T_PARENT${NC}"
                read -p "  Wipe Repos? (y/n): " wipe_choice
                [[ "$wipe_choice" =~ ^[Yy]$ ]] && find "$T_PARENT" -maxdepth 1 -type d -not -name "$T_FOLDER" -not -path "$T_PARENT" -exec rm -rf {} +
            fi
        fi
    done < "$HEIST_DB"

    sync_worker() {
        local U=$1; local R=$2; local B=$3; local NAME=$(basename "$R")
        if [ -d "$R" ]; then
            (git -C "$R" fetch origin "$B" --quiet && git -C "$R" rebase origin/"$B" --quiet) &>/dev/null
        else
            mkdir -p "$(dirname "$R")"; git clone --single-branch -b "$B" "$U" "$R" --quiet &>/dev/null
        fi
        echo -e "  ${C_ACCENT}✔${NC} $NAME"
    }
    export -f sync_worker; export C_ACCENT NC
    while IFS='|' read -r URL REL BRANCH; do
        [[ "$URL" =~ ^#.* ]] || [ -z "$URL" ] && continue
        sync_worker "$URL" "$REL" "$BRANCH" & 
    done < "$HEIST_DB"
    wait; read -p "  Finished..."
}

run_dual_patch() {
    local db=$1; local mode=$2
    show_banner
    echo -e "  ${C_GOSSIP}🔱 GIT ${mode^^}...${NC}\n"
    while IFS='|' read -r TARGET_DIR R_NAME R_URL COMMIT_HASH; do
        [[ "$TARGET_DIR" =~ ^#.* ]] || [ -z "$TARGET_DIR" ] && continue
        if [ -d "$TARGET_DIR" ]; then
            cd "$TARGET_DIR"
            echo -ne "  ➜ [${C_GOSSIP}$TARGET_DIR${NC}] ${COMMIT_HASH:0:7}... "
            git fetch "$R_NAME" "$R_URL" --quiet 2>/dev/null
            local cmd="git cherry-pick $COMMIT_HASH"
            [[ "$mode" == "revert" ]] && cmd="git revert --no-edit $COMMIT_HASH"
            if $cmd &>/dev/null; then 
                echo -e "${C_ACCENT}[OK]${NC}"
            else 
                echo -e "  ${C_DANGER}[FAIL]${NC}"
                $SHELL
            fi
            cd - > /dev/null
        fi
    done < "$db"
    read -p "  Finished..."
}

run_upload() {
    source "$CONF" 2>/dev/null
    show_banner
    echo -e "  ${C_PRIME}📦 BUILD DISPATCHER${NC}\n"
    read -p "  📱 Device: " DEV; [[ "$DEV" == "b" ]] && return
    
    DEVICE_LOWER=$(echo "$DEV" | tr '[:upper:]' '[:lower:]')
    ROM_LOWER=$(echo "$ROM_NAME" | tr '[:upper:]' '[:lower:]')
    TARGET_EXT="*.zip"

    find_files() {
        local EXT=$1
        MATCHES=()
        PROBABLE_DIR="$BASE_SEARCH_ROOT/out/target/product/$DEVICE_LOWER"
        
        echo -e "  ${C_GOSSIP}🔍 Checking standard out/ folder for $EXT...${NC}"
        if [ -d "$PROBABLE_DIR" ]; then
            mapfile -t MATCHES < <(find "$PROBABLE_DIR" -maxdepth 2 -type f -name "$EXT" -ipath "*$ROM_LOWER*" -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk '{print $2}')
        fi

        if [ ${#MATCHES[@]} -eq 0 ]; then
            echo -e "  ${C_WARN}⏳ Deep scanning root for $EXT...${NC}"
            mapfile -t MATCHES < <(find "$BASE_SEARCH_ROOT" \( -path "*/.repo" -o -path "*/prebuilts" -o -path "*/external" \) -prune -o -type f -name "$EXT" -ipath "*$DEVICE_LOWER*" -ipath "*$ROM_LOWER*" -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk '{print $2}')
        fi
    }

    find_files "$TARGET_EXT"

    if [ ${#MATCHES[@]} -eq 0 ]; then
        echo -e "  ${C_DANGER}✖ No ZIP files found.${NC}"
        echo -e "  ${C_GOSSIP}Try searching for a different extension?${NC}"
        echo -e "  ${C_ACCENT}1)${NC} .json"
        echo -e "  ${C_ACCENT}2)${NC} .txt"
        echo -e "  ${C_ACCENT}3)${NC} .img"
        echo -e "  ${C_ACCENT}4)${NC} Custom Extension"
        echo -e "  ${C_WARN}b)${NC} Cancel"
        read -p "  Selection » " ext_choice
        case $ext_choice in
            1) TARGET_EXT="*.json" ;;
            2) TARGET_EXT="*.txt" ;;
            3) TARGET_EXT="*.img" ;;
            4) read -p "  Enter extension: " c_ext; TARGET_EXT="*$c_ext" ;;
            *) return ;;
        esac
        find_files "$TARGET_EXT"
    fi

    if [ ${#MATCHES[@]} -eq 0 ]; then echo -e "  ${C_DANGER}✖ No files found.${NC}"; read -p "  Finished..."; return; fi

    UPLOAD_LIST=()
    if [ ${#MATCHES[@]} -gt 1 ]; then
        echo -e "\n  ${C_WARN}Multiple files found:${NC}"
        for i in "${!MATCHES[@]}"; do echo -e "  ${C_ACCENT}$((i+1)))${NC} ${MATCHES[$i]}"; done
        echo -e "  ${C_ACCENT}m)${NC} Bulk Select (All)"
        read -p "  Selection » " m_choice
        if [[ "$m_choice" == "m" ]]; then UPLOAD_LIST=("${MATCHES[@]}"); else UPLOAD_LIST=("${MATCHES[$((m_choice-1))]}"); fi
    else
        echo -e "  ${C_ACCENT}✔ Located File:${NC}\n  ${C_GREY}${MATCHES[0]}${NC}"
        UPLOAD_LIST=("${MATCHES[0]}")
    fi

    for CURRENT_FILE in "${UPLOAD_LIST[@]}"; do
        BUILD_ZIP="$CURRENT_FILE"
        FILENAME=$(basename "$BUILD_ZIP")
        
        echo -e "\n  ${C_PRIME}💎 Processing: $FILENAME${NC}"

        read -p "  📝 Rename build? (y/n): " ren_choice
        if [[ "$ren_choice" =~ ^[Yy]$ ]]; then
            AUTO_NAME="${ROM_NAME}-v${ROM_VERSION}-${DEV}${TARGET_EXT#*}"
            SAVED_NAME=$(cat "$LAST_NAME_DB" 2>/dev/null)
            echo -e "  ${C_ACCENT}1)${NC} Auto: $AUTO_NAME"
            echo -e "  ${C_ACCENT}2)${NC} Custom Name"
            [ -n "$SAVED_NAME" ] && echo -e "  ${C_ACCENT}3)${NC} Last Used: $SAVED_NAME"
            read -p "  Choice » " rc
            if [[ "$rc" == "1" ]]; then NEW_NAME="$AUTO_NAME"; elif [[ "$rc" == "3" ]] && [ -n "$SAVED_NAME" ]; then NEW_NAME="$SAVED_NAME"
            else read -p "  Enter Name: " NEW_NAME; [[ "$NEW_NAME" != *${TARGET_EXT#*} ]] && NEW_NAME="${NEW_NAME}${TARGET_EXT#*}"; echo "$NEW_NAME" > "$LAST_NAME_DB"; fi
            mv "$BUILD_ZIP" "$(dirname "$BUILD_ZIP")/$NEW_NAME"; BUILD_ZIP="$(dirname "$BUILD_ZIP")/$NEW_NAME"; FILENAME="$NEW_NAME"
        fi

        SIZE=$(du -h "$BUILD_ZIP" | awk '{print $1}')

        echo -e "\n  ${C_GREY}DESTINATION:${NC}"
        echo -e "  ${C_ACCENT}1)${NC} Default"
        echo -e "  ${C_ACCENT}2)${NC} Bookmarks"
        echo -e "  ${C_ACCENT}3)${NC} Custom Path"
        read -p "  Selection » " up_choice
        case $up_choice in
            1) FINAL_DEST=$([[ "$PROVIDER_TYPE" == "RCLONE" ]] && echo "${REMOTE_PATH}:${CLOUD_BASE}" || echo "${REMOTE_PATH}/${CLOUD_BASE}") ;;
            2) local i=1; declare -A bks; while IFS= read -r l; do [[ "$l" =~ ^#.* ]] || [ -z "$l" ] && continue; bks[$i]=$l; echo -e "  $i) $l"; ((i++))done < "$BOOKMARKS_FILE"
               read -p "  Bookmark #: " bc; FINAL_DEST=${bks[$bc]} ;;
            3) read -p "  Custom Path: " FINAL_DEST ;;
            *) continue ;;
        esac
        
        echo -ne "  ${C_GOSSIP}🛡️  Checking for existing...${NC}"
        EXISTS=false
        if [[ "$PROVIDER_TYPE" == "RCLONE" ]]; then rclone lsf "$FINAL_DEST" --include "$FILENAME" &>/dev/null && EXISTS=true
        else ssh "${REMOTE_PATH%%:*}$" "ls ${FINAL_DEST#*:}/$FILENAME" &>/dev/null && EXISTS=true; fi
        
        [ "$EXISTS" = true ] && read -p "  ⚠️  Overwrite? (y/n): " ovr && [[ ! "$ovr" =~ ^[Yy]$ ]] && continue

        echo -e "\n  ${C_WARN}📤 Uploading...${NC}"
        UP_OK=false
        if [ "$PROVIDER_TYPE" == "SF" ]; then
            rsync -avP -e ssh "$BUILD_ZIP" "$FINAL_DEST/" && UP_OK=true
            DL_URL="https://sourceforge.net/projects/${REMOTE_PATH%%:*}/files/${CLOUD_BASE}/${FILENAME}/download"
        else
            rclone copy "$BUILD_ZIP" "$FINAL_DEST" --progress && UP_OK=true
            DL_URL=$(rclone link "$FINAL_DEST/$FILENAME" 2>/dev/null || echo "https://projects.infinity-x.org")
        fi
        
        if [ "$UP_OK" == true ]; then
            echo -e "  ${C_ACCENT}✔ Upload Complete!${NC}"
            if [ -n "$TG_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
                echo -ne "  ${C_GOSSIP}📱 Sending Telegram Notification...${NC}"
                MD5=$(md5sum "$BUILD_ZIP" | awk '{print $1}')
                
                # --- TELEGRAM FORMATTING ---
                MSG="🚀 *Build Ready!*%0A"
                MSG+="%0A🔢 *Version:* $ROM_VERSION"
                MSG+="%0A📱 *Device:* ${DEV^^}"
                MSG+="%0A🛡 *Status:* $ROM_STATUS"
                MSG+="%0A📦 *Filename:* \`$FILENAME\`"
                MSG+="%0A📊 *Size:* $SIZE"
                MSG+="%0A🔐 *MD5:* \`$MD5\`"
                MSG+="%0A━━━━━━━━━━━━━━━━━━━━"
                
                BUTTON="{\"inline_keyboard\":[[{\"text\":\"📥 Download Now\",\"url\":\"${DL_URL}\"}]]}"
                RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
                    --data-urlencode "chat_id=$TG_CHAT_ID" \
                    --data-urlencode "text=$MSG" \
                    --data-urlencode "parse_mode=Markdown" \
                    --data-urlencode "reply_markup=$BUTTON")
                
                [[ "$RESPONSE" == *"\"ok\":true"* ]] && echo -e " ${C_ACCENT}[SENT]${NC}" || echo -e " ${C_DANGER}[FAIL]${NC}"
            fi
        fi
    done
    read -p "  Batch Finished..."
}

# --- 4. MAIN HUB ---
[ ! -f "$CONF" ] && touch "$CONF" "$BOOKMARKS_FILE" "$HEIST_DB" "$CHERRY_DB" "$REVERT_DB" "$LAST_SESSION"
source "$CONF" 2>/dev/null

while true; do
    show_banner
    echo -e "  ${C_GREY}ACTIONS${NC}"
    echo -e "  ${C_ACCENT}1)${NC} Upload Build"
    echo -e "  ${C_ACCENT}2)${NC} Cherry-pick"
    echo -e "  ${C_ACCENT}3)${NC} Git Revert"
    echo -e "  ${C_ACCENT}4)${NC} Repo Heist"
    echo -e "  ${C_PRIME}5)${NC} Master Sequence"
    echo -e ""
    echo -e "  ${C_GREY}LISTS${NC}"
    echo -e "  ${C_ACCENT}6)${NC} Bookmarks"
    echo -e "  ${C_ACCENT}7)${NC} Cherry-picks"
    echo -e "  ${C_ACCENT}8)${NC} Reverts"
    echo -e "  ${C_ACCENT}9)${NC} Heists"
    echo -e ""
    echo -e "  ${C_GREY}SYSTEM${NC}"
    echo -e "  ${C_ACCENT}10)${NC} Manual Config"
    echo -e "  ${C_ACCENT}11)${NC} Setup Wizard"
    echo -e "  ${C_ACCENT}12)${NC} Quick Update"
    echo -e "  ${C_DANGER}0)${NC} Exit"
    echo -e "  "
    read -p "  Selection » " choice
    case $choice in
        1) run_upload ;; 
        2) run_dual_patch "$CHERRY_DB" "cherry-pick" ;; 
        3) run_dual_patch "$REVERT_DB" "revert" ;;
        4) run_heist ;; 
        5) run_heist; run_dual_patch "$CHERRY_DB" "cherry-pick"; run_dual_patch "$REVERT_DB" "revert"; run_upload; read -p "  Finished..." ;;
        6) manage_list "$BOOKMARKS_FILE" "BOOKMARKS" ;; 
        7) manage_list "$CHERRY_DB" "CHERRY-LIST" ;;
        8) manage_list "$REVERT_DB" "REVERT-LIST" ;; 
        9) manage_list "$HEIST_DB" "HEIST-LIST" ;;
        10) nano "$CONF" && source "$CONF" ;; 
        11) run_setup_wizard ;; 
        12) update_version_only ;;
        0) read -p "  ⚠️  Exit? (y/n): " ce; [[ "$ce" =~ ^[Yy]$ ]] && exit 0 ;;
    esac
done
