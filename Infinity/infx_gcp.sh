#!/bin/bash

# --- CONFIGURATION ---
ROM_VERSION="3.6"
REMOTE_PERSONAL="Pyrtle93"
BASE_BRANCH="16"

# --- COLORS ---
hex_fg() { echo -ne "\033[38;2;$1;$2;$3m"; }
NC='\033[0m'
C_ACCENT=$(hex_fg 3 218 198)
C_PRIME=$(hex_fg 187 134 252)
C_DANGER=$(hex_fg 255 85 85)
C_GOSSIP=$(hex_fg 139 233 253)
C_WARN=$(hex_fg 255 184 108)

START_TIME=$(date +%s)
TOP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- PRE-FLIGHT: SSH & STATUS ---
echo -e "${C_WARN}Verifying SSH Connections...${NC}"
SERVICES=("github.com" "gitlab.com" "codeberg.org")
for svc in "${SERVICES[@]}"; do
    echo -ne "  󰒍 Testing $svc... "
    ssh -T -o ConnectTimeout=5 -o StrictHostKeyChecking=no git@$svc 2>&1 | grep -Eiq "successfully|welcome|authenticated" && \
    echo -e "${C_ACCENT}[ OK ]${NC}" || echo -e "${C_DANGER}[ FAIL ]${NC}"
done

echo -e "\n${C_WARN}Current Repository Status:${NC}"
CHECK_DIRS=("frameworks/base" "vendor/infinity" "vendor/google/gms" "build/make")
for dir in "${CHECK_DIRS[@]}"; do
    if [ -d "$TOP/$dir" ]; then
        cd "$TOP/$dir"
        B_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        [[ "$B_NAME" == "HEAD" ]] && B_NAME="${C_DANGER}DETACHED${NC}" || B_NAME="${C_ACCENT}$B_NAME${NC}"
        echo -e "  ➜ $dir: [ $B_NAME ]"
    fi
done

# --- SHALLOW CHECK ---
echo -e "\n${C_WARN}Checking for shallow repositories...${NC}"
FORCED_FULL=("frameworks/base" "vendor/infinity" "build/make")
for dir in "${FORCED_FULL[@]}"; do
    if [ -d "$TOP/$dir" ] && [ -f "$TOP/$dir/.git/shallow" ]; then
        echo -ne "  ${C_PRIME}󰇚 $dir is shallow. Fixing locally...${NC} "
        cd "$TOP/$dir"
        git fetch --unshallow --quiet 2>/dev/null || git fetch --depth=1000 --quiet 2>/dev/null
        echo -e "${C_ACCENT}[ DONE ]${NC}"
    fi
done

# --- HELPERS ---
find_best_branch() {
    local url=$1
    local dir=$2
    local branches
    branches=$(git ls-remote --heads "$url" 2>/dev/null | awk '{print $2}' | sed 's|refs/heads/||')
    case "$dir" in
        "vendor/infinity")    echo "$branches" | grep -w "p${ROM_VERSION}.2" || echo "$branches" | grep "p${ROM_VERSION}" | tail -1 ;;
        "vendor/google/gms")  echo "$branches" | grep -w "gang" ;;
        "frameworks/base")    echo "$branches" | grep -w "p${ROM_VERSION}" ;;
        *)                    echo "$BASE_BRANCH" ;;
    esac
}

generate_new_branch_name() {
    local base_name="p${ROM_VERSION}"
    local count=0
    local final_name="$base_name"
    local all_known_branches=$(git branch -a)
    while echo "$all_known_branches" | grep -q "$final_name$"; do
        ((count++))
        final_name="${base_name}.${count}"
    done
    echo "$final_name"
}

# --- REVERT LIST ---
REVERTS=(
    "build/make|4e5717d88102bdbe664c03705922c29f6393dc29"
)

# --- PATCH LIST ---
PATCHES=(
    "vendor/infinity|Pyrtle93|git@github.com:PisselShit/vendor_infinity.git|7a41757560843e3ee8dedd43aa709a64aee3f496"
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

SUCCESS_COUNT=0
EXISTING_COUNT=0
CONFLICT_COUNT=0
declare -A FETCHED_SESS
declare -A REPOS_TO_PUSH

# --- EXECUTE REVERTS ---
echo -e "${C_ACCENT}Initiating Revert Session...${NC}\n"
for rev in "${REVERTS[@]}"; do
    IFS='|' read -r TARGET_DIR COMMIT_HASH <<< "$rev"
    FULL_PATH="$TOP/$TARGET_DIR"
    SHORT_HASH=$(echo $COMMIT_HASH | cut -c1-7)
    cd "$FULL_PATH" || continue

    # Check if commit exists to revert
    if ! git merge-base --is-ancestor "$COMMIT_HASH" HEAD 2>/dev/null; then
        echo -e "  ${C_GOSSIP}[ $TARGET_DIR ]${NC} $SHORT_HASH... ${C_WARN}[ NOT IN HISTORY / ALREADY REVERTED ]${NC}"
        continue
    fi

    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "$BASE_BRANCH" ]]; then
        git fetch "$REMOTE_PERSONAL" --quiet 2>/dev/null
        NEW_BRANCH=$(generate_new_branch_name)
        echo -e "  ${C_PRIME}󰁹 Branching $NEW_BRANCH in $TARGET_DIR...${NC}"
        git checkout -b "$NEW_BRANCH" --quiet
        CURRENT_BRANCH="$NEW_BRANCH"
    fi
    REPOS_TO_PUSH["$TARGET_DIR"]="$CURRENT_BRANCH"

    echo -ne "  ${C_GOSSIP}[ $TARGET_DIR ]${NC} Reverting $SHORT_HASH... "
    if git revert "$COMMIT_HASH" --no-edit &>/dev/null; then
        echo -e "${C_ACCENT}[ SUCCESS ]${NC}"
        ((SUCCESS_COUNT++))
    else
        # Check if the revert is failing because the change is already gone
        if git status | grep -q "nothing to commit"; then
            echo -e "${C_WARN}[ ALREADY REVERTED ]${NC}"
            ((EXISTING_COUNT++))
        else
            echo -e "${C_DANGER}[ CONFLICT ]${NC}"
            ((CONFLICT_COUNT++))
        fi
        git revert --abort &>/dev/null
    fi
done

# --- EXECUTE CHERRY-PICKS ---
echo -e "\n${C_ACCENT}Initiating Cherry-Pick Session...${NC}\n"
for patch in "${PATCHES[@]}"; do
    IFS='|' read -r TARGET_DIR R_NAME R_URL COMMIT_HASH <<< "$patch"
    FULL_PATH="$TOP/$TARGET_DIR"
    SHORT_HASH=$(echo $COMMIT_HASH | cut -c1-7)
    cd "$FULL_PATH" || continue

    if git rev-parse --verify "$COMMIT_HASH" >/dev/null 2>&1 && git merge-base --is-ancestor "$COMMIT_HASH" HEAD; then
        echo -e "  ${C_GOSSIP}[ $TARGET_DIR ]${NC} $SHORT_HASH... ${C_WARN}[ ALREADY APPLIED ]${NC}"
        ((EXISTING_COUNT++))
        continue
    fi

    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$TARGET_DIR" != "vendor/google/gms" ]]; then
        if [[ "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "$BASE_BRANCH" ]]; then
            git fetch "$REMOTE_PERSONAL" --quiet 2>/dev/null
            NEW_BRANCH=$(generate_new_branch_name)
            echo -e "  ${C_PRIME}󰁹 Branching $NEW_BRANCH in $TARGET_DIR...${NC}"
            git checkout -b "$NEW_BRANCH" --quiet
            CURRENT_BRANCH="$NEW_BRANCH"
        fi
        REPOS_TO_PUSH["$TARGET_DIR"]="$CURRENT_BRANCH"
    fi

    echo -ne "  ${C_GOSSIP}[ $TARGET_DIR ]${NC} $SHORT_HASH... "
    if [[ -z "${FETCHED_SESS[$TARGET_DIR]}" ]]; then
        R_BRANCH=$(find_best_branch "$R_URL" "$TARGET_DIR")
        git fetch "$R_NAME" "$R_BRANCH" --quiet 2>/dev/null
        FETCHED_SESS[$TARGET_DIR]="$R_BRANCH"
    fi
    
    if git cherry-pick "$COMMIT_HASH" &>/dev/null; then
        echo -e "${C_ACCENT}[ SUCCESS ]${NC}"
        ((SUCCESS_COUNT++))
    else
        git status | grep -q "nothing to commit" && echo -e "${C_WARN}[ ALREADY APPLIED ]${NC}" || echo -e "${C_DANGER}[ CONFLICT ]${NC}"
        git cherry-pick --abort &>/dev/null
        ((CONFLICT_COUNT++))
    fi
done

# --- PUSH ---
if [ ${#REPOS_TO_PUSH[@]} -gt 0 ]; then
    echo -ne "\n${C_GOSSIP}🚀 Push branches to $REMOTE_PERSONAL? (y/n): ${NC}"
    read -n 1 -r REPLY < /dev/tty
    echo "" 
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for dir in "${!REPOS_TO_PUSH[@]}"; do
            BRANCH_NAME="${REPOS_TO_PUSH[$dir]}"
            cd "$TOP/$dir"
            echo -ne "  Syncing & Pushing $dir... "
            git fetch "$REMOTE_PERSONAL" "+refs/heads/*:refs/remotes/$REMOTE_PERSONAL/*" --quiet 2>/dev/null
            git push "$REMOTE_PERSONAL" "HEAD:refs/heads/$BRANCH_NAME" --force --quiet && echo -e "${C_ACCENT}[ DONE ]${NC}" || echo -e "${C_DANGER}[ FAILED ]${NC}"
        done
    fi
fi

DURATION=$(( $(date +%s) - START_TIME ))
echo -e "\n${C_PRIME}Session completed in ${DURATION}s.${NC}"
