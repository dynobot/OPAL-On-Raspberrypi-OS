#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if the first argument is "auto" for non-interactive mode
if [ "$1" == "auto" ]; then
    NON_INTERACTIVE=true
else
    NON_INTERACTIVE=false
fi

# Function to prompt the user and run a command
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
# Downloads the Roon Bridge installer using curl, following redirects (-L) and saving as original filename (-O).
prompt_and_run "3. Would you like to download the Roon Bridge installer?" "curl -O -L https://download.roonlabs.com/builds/roonbridge-installer-linuxarmv8.sh"

# Step 4: Install Roon Bridge
# This step checks for the downloaded installer file before attempting to install it.
if [ -f "roonbridge-installer-linuxarmv8.sh" ]; then
    prompt_and_run "4. Would you like to install Roon Bridge?" "chmod +x roonbridge-installer-linuxarmv8.sh && sudo ./roonbridge-installer-linuxarmv8.sh"
else
    echo "Roon Bridge installer not found. Skipping installation."
fi

# Step 5: Build OPAL
# This step downloads the OPAL build script, checks for its existence, then makes it executable and runs it.
if [ -f "build_opal.sh" ]; then
    echo "OPAL build script 'build_opal.sh' already exists. Skipping download."
    prompt_and_run "5. Would you like to build OPAL now using the existing script?" "chmod +x build_opal.sh && ./build_opal.sh"
else
    prompt_and_run "5. Would you like to build OPAL now?" "curl -O -L https://github.com/dynobot/OPAL-On-Raspberrypi-OS/raw/main/build_opal.sh && chmod +x build_opal.sh && ./build_opal.sh"
fi

echo "Script finished."
