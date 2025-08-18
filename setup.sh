#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if the first argument is "auto" for non-interactive mode
if [ "$1" == "auto" ]; then
    NON_INTERACTIVE=true
else
    NON_INTERACTIVE=false
fi

# Function to prompt the user
prompt_and_run() {
    local prompt_message="$1"
    local command_to_run="$2"

    if [ "$NON_INTERACTIVE" = true ]; then
        echo "Auto mode enabled. Continuing with action..."
        eval "$command_to_run"
    else
        read -p "$prompt_message (y/N)? " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Continuing with action..."
            eval "$command_to_run"
            echo "Action complete."
        else
            echo "Skipping action."
        fi
    fi
}

echo "Starting system installations..."

# Step 1: System Update and Upgrade
prompt_and_run "1. Would you like to update and upgrade all packages?" "sudo apt update && sudo apt upgrade -y"

# Step 2: Install Squeezelite
prompt_and_run "2. Would you like to install Squeezelite?" "sudo apt install -y squeezelite"

# Step 3: Download Roon Bridge Installer
# Corrected: Removed the erroneous backtick after .sh
prompt_and_run "3. Would you like to download the Roon Bridge installer?" "wget https://download.roonlabs.com/builds/roonbridge-installer-linuxarmv8.sh"

# Step 4: Install Roon Bridge
# This step checks for the file before attempting to install
if [ -f "roonbridge-installer-linuxarmv8.sh" ]; then
    prompt_and_run "4. Would you like to install Roon Bridge?" "sudo chmod +x roonbridge-installer-linuxarmv8.sh && sudo ./roonbridge-installer-linuxarmv8.sh"
else
    echo "Roon Bridge installer not found. Skipping installation."
fi

echo "Script finished."
