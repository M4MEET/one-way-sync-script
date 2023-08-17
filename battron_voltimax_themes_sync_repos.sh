#!/bin/bash

# 🎨 Adding some colors for an interactive touch
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 🛠 Config
source config.txt

# 📬 Function to send a Slack notification
send_slack_notification() {
    local message="$1"
    # Escape special characters in message to avoid breaking JSON
    message=$(echo "$message" | sed 's/"/\\"/g')
    curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" "$webhook_url"
}

# 📂 Directories to be potentially synced
declare -a directories=(
  "Resources/app/storefront/src/scss/base.scss"
  "Resources/app/storefront/src/scss/overrides.scss"
  "Resources/public"
  "Resources/snippet"
  "Resources/views/storefront"
)

log_file="sync_log_$(date '+%Y%m%d').log"

# 🖋 Log messages with style!
log_message() {
    echo -e "${GREEN}🚀 $1${NC}" | tee -a "$log_file"
}

# 🤔 Selective Syncing
selected_directories=()

echo -e "${YELLOW}🤓 Which directories would you like to sync?${NC}"
echo -e "(Enter directory numbers separated by spaces for multiple selections, ${GREEN}'a'${NC} for all, or ${RED}'q'${NC} to quit.)"

# 🌍 Add an 'All' option to the directories list for selection.
all_option="All"
extended_directories=("${directories[@]}" "$all_option")

select dir in "${extended_directories[@]}"; do
    case $REPLY in
        a|A)
            selected_directories=("${directories[@]}")
            echo -e "${GREEN}🔥 All directories selected!${NC}"
            break
            ;;
        q|Q)
            echo -e "${RED}👋 Okay! Maybe next time.${NC}"
            break
            ;;
        *)
            # Check if the selected number is valid
            if [[ $REPLY -ge 1 ]] && [[ $REPLY -le ${#extended_directories[@]} ]]; then
                if [[ "$dir" == "$all_option" ]]; then
                    selected_directories=("${directories[@]}")
                    break
                else
                    # If this directory was not already selected, add it to the selected directories
                    if ! [[ "${selected_directories[@]}" =~ "${dir}" ]]; then
                        selected_directories+=("$dir")
                    fi
                fi
            else
                echo -e "${RED}🤔 Hmm. Invalid selection. Let's try that again.${NC}"
            fi
            ;;
    esac

    # 📢 Print a message after a directory is selected
    if [ -n "$dir" ] && [[ ! "$dir" == "$all_option" ]]; then
        echo -e "${GREEN}👍 $dir has been selected! Continue selecting, type 'a' for all, or 'q' to wrap up.${NC}"
    fi
done

# ✅ Verification, print out the selected directories.
echo -e "${GREEN}📝 You've chosen the following directories:${NC}"
for dir in "${selected_directories[@]}"; do
    echo -e " - $dir"
done

# 📊 Summary initial values
copied_files=0

# 🕵️ Check current branch
cd "$VOLTIMAX_PATH"
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "master" ]; then
    log_message "⚠️ You're not on the master branch. Current branch: $current_branch"
    exit 1
fi

# 🚧 Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    log_message "⚠️ There's some work in progress. Please stash or commit them first."
    exit 1
fi

# 🤔 Prompt for confirmation
read -p "🚨 This will sync directories and might overwrite files. Still good to go? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# 📦 Backup
backup_zip="$VOLTIMAX_PATH/backup_$(date '+%Y%m%d%H%M%S').zip"
log_message "🔐 Creating a backup ZIP of Voltimax..."

# Only backup the directories being synced
for dir in "${selected_directories[@]}"; do
    if [[ -e "$VOLTIMAX_PATH/src/$dir" ]]; then
        zip -r $backup_zip "$VOLTIMAX_PATH/src/$dir" || log_message "❌ Oops! Failed to create a backup ZIP for $dir"
    else
        log_message "❌ Oh no! Path not found: $VOLTIMAX_PATH/src/$dir"
    fi
done

# 🔄 Loop through each directory to sync
for dir in "${selected_directories[@]}"
do
    log_message "🛸 Beaming up $dir..."

    # Check if the $dir is a directory or a file before rsyncing
    if [[ -d "$BATTRON_THEME_PATH/src/$dir" ]]; then
        # Directory rsync
        rsync_output=$(rsync -av "$BATTRON_THEME_PATH/src/$dir/" "$VOLTIMAX_PATH/src/$dir/")
    else
        # File rsync
        rsync_output=$(rsync -av "$BATTRON_THEME_PATH/src/$dir" "$VOLTIMAX_PATH/src/$dir")
    fi

    rsync_status=$?
    copied_files_count=$(echo "$rsync_output" | wc -l)
    copied_files=$((copied_files + copied_files_count))

    if [[ $rsync_status -ne 0 ]]; then
        log_message "❌ Yikes! Had some trouble with $dir"
    fi
done

log_message "🎉 Woo-hoo! The files are now lounging comfortably on the other side!"

# 📝 Custom git operations
read -p "🗣 Time for your commit message: " commit_message
git add src/Resources
git commit -m "$commit_message"

read -p "🔀 Which branch are we pushing to? " branch
# Check if branch exists
if ! git show-ref --verify --quiet refs/heads/"$branch"; then
    log_message "⚠️ Looks like the $branch branch is MIA. Let's create and switch to it..."
    git checkout -b "$branch"
fi
git push origin "$branch"

log_message "📚 The library's refreshed! (I mean, the git repository)"
log_message "🥳 Done and dusted! Your files are kicking back at their new pad. You rock!"

# 📄 Summary
echo -e "${GREEN}🔖 Summary:${NC}"
echo -e "📋 Copied files: $copied_files"

# 🖥 Notification (Mac-specific)
if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e 'display notification "🚀 Syncing Complete" with title "Sync Script"'
fi

# 🍹 Send playful Slack notifications
send_slack_notification "🚀 Mission complete! Your files just took a wild ride!"
send_slack_notification "🍹 Your files are now sipping mojitos at their new home in Voltimax"
send_slack_notification "🎉 Library updated! Double-check and roll it out!"
