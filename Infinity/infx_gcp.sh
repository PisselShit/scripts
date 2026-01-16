#!/bin/bash

# --- HEX COLORS ---
hex_fg() { echo -ne "\033[38;2;$1;$2;$3m"; }
NC='\033[0m'
C_ACCENT=$(hex_fg 3 218 198)
C_PRIME=$(hex_fg 187 134 252)
C_DANGER=$(hex_fg 255 85 85)
C_GOSSIP=$(hex_fg 139 233 253)
C_WARN=$(hex_fg 255 184 108)

# --- DIRECTORY INTELLIGENCE ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- SANITY CHECK ---
if [ ! -d "$TOP/.repo" ]; then
    echo -e "${C_DANGER}❌ ABORTING HEIST!${NC}"
    echo -e "${C_WARN}Target root not found at:${NC} $TOP"
    exit 1
fi

# --- PERSONALITY ENGINE ---
MSG_START=("Initializing neural link..." "Accessing the mainframes..." "Preparing the heist...")
MSG_MID=("Injecting code..." "Slicing through dependencies..." "Bypassing repo security...")
MSG_END=("Heist successful. Source is locked." "All systems green.")

START_TXT=${MSG_START[$RANDOM % ${#MSG_START[@]}]}
MID_TXT=${MSG_MID[$RANDOM % ${#MSG_MID[@]}]}
END_TXT=${MSG_END[$RANDOM % ${#MSG_END[@]}]}

# --- YOUR COMMITS ---
PATCHES=(
    "vendor/infinity|Pyrtle93|git@github.com:PisselShit/vendor_infinity.git|dc68934d6a22e1fb14035192418bc8dbb31a0c70"
    "vendor/infinity|Pyrtle93|git@github.com:PisselShit/vendor_infinity.git|ce9a150a85e91c0f750016d43acc1ecf75273fd4"
    "vendor/infinity|Pyrtle93|git@github.com:PisselShit/vendor_infinity.git|e5ac5cf3347c5fd764c8346b2cd5cfe3bb6710ca"
    "vendor/infinity|Pyrtle93|git@github.com:PisselShit/vendor_infinity.git|c031c4de5842e7297f6e7063013a421a85a2c7b4"
    "vendor/google/gms|Pyrtle93|git@gitlab.com:Pyrtle93/android_vendor_google_gms.git|13797a23ed094bca435dafb978537b28c86c9da3"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|262260f2275f10b82fc2a87ed96f956efd9b1cd7"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|0fa111eb79eb5079a8dc869b91189df1da453b77"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|011ed3f54b808a299fb1b3dd0a2a3896f96345f7"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|a230be8e59efe326c98f474d59408820d6165632"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|1402f464be0817eb9f2ffc023aff4b2078cd3d3c"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|ef1aa4b21a060fb48ab9b0e3692ef92873f9b789"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|4441b2dc58555a17ccc328b0fc08bb7eaeead4f4"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|0113de7b5a32b152a696e1a8e5bc65ab0c165ff2"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|935175cb6c4a325cd1543806e6f78185838c86b4"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|e873f41fbaffed5cd3c6c414a46fb559579ac572"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|f1519df9c73eba6d5d51a875cfecac327623292a"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|d1ffea3fceedc6f38016a11482a6ae56696c4428"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|b396453ccba81ba4a3a6ca60e0339b4164135bab"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|efa84c3ed4cf99d8e8e1177af362bfe1b3b778ce"
    "frameworks/base|Pyrtle93|git@codeberg.org:Pyrtle93/frameworks_base.git|311655d9bd2fcb709791d1ad061acca1f9a2f6b4"
)

# --- START ---
echo -e "${C_PRIME}󱐋 $START_TXT${NC}"
echo -e "${C_WARN}󱗘 $MID_TXT${NC}\n"

SKIPPED_LIST=()

for patch in "${PATCHES[@]}"; do
    IFS='|' read -r TARGET_DIR R_NAME R_URL COMMIT_HASH <<< "$patch"
    FULL_PATH="$TOP/$TARGET_DIR"
    SHORT_HASH=$(echo $COMMIT_HASH | cut -c1-7)

    if [ ! -d "$FULL_PATH" ]; then
        echo -e "  ${C_DANGER}✘ Error: $TARGET_DIR not found! Skipping.${NC}"
        continue
    fi

    cd "$FULL_PATH" || continue
    
    [[ $(git remote) =~ "$R_NAME" ]] && git remote set-url "$R_NAME" "$R_URL" || git remote add "$R_NAME" "$R_URL"
    
    if git rev-parse --quiet --verify "${COMMIT_HASH}^{commit}" >/dev/null 2>&1 && \
       git merge-base --is-ancestor "$COMMIT_HASH" HEAD >/dev/null 2>&1; then
        echo -e "  ${C_ACCENT}󰄬 $SHORT_HASH already present in $TARGET_DIR. Skipping.${NC}"
        continue
    fi
    
    echo -ne "  ${C_GOSSIP}CP $SHORT_HASH -> $TARGET_DIR... ${NC}"
    if git fetch "$R_NAME" --quiet; then
        if git cherry-pick "$COMMIT_HASH" &>/dev/null; then
            echo -e "✅"
        else
            if [ -z "$(git status --porcelain)" ]; then
                 echo -e "✅ ${C_ACCENT}(Applied)${NC}"
                 git cherry-pick --abort &>/dev/null
            else
                echo -e "❌ ${C_DANGER}CONFLICT! Auto-skipping...${NC}"
                SKIPPED_LIST+=("$TARGET_DIR | $SHORT_HASH")
                git cherry-pick --skip &>/dev/null
            fi
        fi
    else
        echo -e "❌ ${C_DANGER}FETCH FAILED${NC}"
    fi
done

if [ ${#SKIPPED_LIST[@]} -ne 0 ]; then
    echo -e "\n${C_DANGER}⚠️  WARNING: SOME PATCHES SKIPPED${NC}"
    for item in "${SKIPPED_LIST[@]}"; do echo -e "  ${C_WARN}󰔶 $item${NC}"; done
fi

echo -e "\n${C_ACCENT}󰄬 $END_TXT${NC}"
