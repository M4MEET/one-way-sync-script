#!/bin/bash

# Config
source config.txt

# Function to send a Slack notification
send_slack_notification() {
    local message="$1"
    curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" $webhook_url
}

# Directories to be potentially synced
declare -a directories=("Resources/app/storefront/src/scss" "Resources/public" "Resources/snippet" "Resources/views/storefront")

log_file="sync_log_$(date '+%Y%m%d').log"

log_message() {
    echo "🚀 $1" | tee -a $log_file
}

# Selective Syncing
selected_directories=()

echo "Which directories would you like to sync?"
echo "(Enter directory numbers separated by spaces for multiple selections, 'a' for all, or 'q' to quit.)"

# Add an 'All' option to the directories list for selection.
all_option="All"
extended_directories=("${directories[@]}" "$all_option")

select dir in "${extended_directories[@]}"; do
    case $REPLY in
        a|A)
            selected_directories=("${directories[@]}")
            break
            ;;
        q|Q)
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
                echo "Invalid selection. Please try again."
            fi
            ;;
    esac

    # Print a message after a directory is selected
    if [ -n "$dir" ] && [[ ! "$dir" == "$all_option" ]]; then
        echo "$dir has been selected. Continue selecting, type 'a' for all, or 'q' to finish."
    fi
done

# Just for verification, print out the selected directories.
echo "You've selected the following directories:"
for dir in "${selected_directories[@]}"; do
    echo " - $dir"
done

# Summary initial values
copied_files=0

# Check current branch
cd $VOLTIMAX_PATH
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "master" ]; then
    log_message "⚠️  You are not on the master branch. Current branch: $current_branch"
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    log_message "⚠️  There are uncommitted changes in the repository. Please commit them first."
    exit 1
fi

# Prompt for confirmation
read -p "This will sync directories and possibly overwrite files. Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Backup
backup_zip="$VOLTIMAX_PATH/backup_$(date '+%Y%m%d%H%M%S').zip"
log_message "🛸 Creating a backup ZIP of Voltimax..."
zip -r $backup_zip $VOLTIMAX_PATH || log_message "❌ Failed to create a backup ZIP"

# Loop through each directory to sync
for dir in "${selected_directories[@]}"
do
    log_message "✨ Beaming up $dir..."
    copied_files=$((copied_files + $(rsync -av $BATTRON_THEME_PATH/src/$dir/ $VOLTIMAX_PATH/src/$dir/ | wc -l)))
    rsync -av $BATTRON_THEME_PATH/src/$dir/ $VOLTIMAX_PATH/src/$dir/ || log_message "❌ Failed to sync $dir"
done

log_message "🎉 Woo-hoo! The files have landed safely on the other side!"

# Custom git operations
read -p "Enter your commit message: " commit_message
git add src/Resources
git commit -m "$commit_message"

read -p "Which branch would you like to push to? " branch
git push origin "$branch"

log_message "📚 The library's been updated! (I mean the git repository)"
log_message "🥳 Mission accomplished! Your files are chilling at their new home. Give yourself a pat on the back!"

# Summary
echo "Summary:"
echo "Copied files: $copied_files"

# Notification
osascript -e 'display notification "Syncing Complete" with title "Sync Script"'

# Send fun Slack notifications
send_slack_notification "🚀 Mission accomplished! Your files have been teleported successfully!"
send_slack_notification "🎉 Backup done and dusted. Files are now sipping cocktails at $backup_zip"
send_slack_notification "📚 Voltimax's library just got updated! Yay!"
