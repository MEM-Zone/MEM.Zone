#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Cask Upgrade
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon /Users/Ioan/Library/Mobile Documents/com~apple~CloudDocs/Raycast/scripts/homebrew-cask-upgrade/homebrew_icon.png
# @raycast.argument1 { "type": "text", "placeholder": "Parameters" }
# @raycast.packageName Brew

# Documentation:
# @raycast.description Upgrades Homebrew Casks
# @raycast.author Ioan Popovici
# @raycast.authorURL https://MEM.Zome

args=$1

if [[ $args = 'all' ]] ; then
    args='--yes --all --include-mas --cleanup'
fi

args=(--yes --all --include-mas --cleanup)

brew cu "${args[@]}"
