#!/bin/bash

# Paths to the repositories
BATTRON_THEME_PATH="/Users/demon/local-dev/src/custom/plugins/ThemeBattronGmbh"
VOLTIMAX_PATH="/Users/demon/local-dev/src/custom/plugins/Voltimax"

# Directories to be synced
declare -a directories=("Resources/public" "Resources/snippet" "Resources/views/storefront")

echo "🚀 Preparing to teleport some files!"

# Loop through each directory and sync
for dir in "${directories[@]}"
do
   echo "✨ Beaming up $dir..."
   rsync -av $BATTRON_THEME_PATH/src/$dir/ $VOLTIMAX_PATH/src/$dir/
done

echo "🎉 Woo-hoo! The files have landed safely on the other side!"

# Commit in voltimax only
cd $VOLTIMAX_PATH
git add src/Resources
git commit -m "Auto-commit: Rescued some files from ThemeBattronGmbh/src/Resources on $(date '+%Y-%m-%d %H:%M:%S')"
git push origin master 

echo "📚 The library's been updated! (I mean the git repository)"

echo "🥳 All done! If this was a pizza delivery, I'd expect a tip by now!"
