#!/bin/bash

# Define the file paths and URLs
CMDLINE_FILE="/boot/firmware/cmdline.txt"
CONFIG_FILE="/boot/firmware/config.txt"
SQUEEZELITE_DIR="/etc/default"
SQUEEZELITE_FILE="$SQUEEZELITE_DIR/squeezelite"
SQUEEZELITE_BAK="$SQUEEZELITE_FILE.bak"

DOWNLOAD_URL_ENDPOINT_SWITCHER="https://raw.githubusercontent.com/dynobot/OPAL-On-Raspberrypi-OS/main/endpoint_switcher.sh"
DOWNLOAD_URL_SOX="https://raw.githubusercontent.com/dynobot/OPAL-On-Raspberrypi-OS/main/sox.sh"
DOWNLOAD_URL_SQUEEZELITE="https://raw.githubusercontent.com/dynobot/OPAL-On-Raspberrypi-OS/main/squeezelite"
DOWNLOAD_URL_OVERRIDE="https://raw.githubusercontent.com/dynobot/OPAL-On-Raspberrypi-OS/main/override.conf"
DOWNLOAD_URL_APPLY_SETTINGS_SH="https://raw.githubusercontent.com/dynobot/OPAL-On-Raspberrypi-OS/main/apply-sys-settings.sh"
DOWNLOAD_URL_APPLY_SETTINGS_SERVICE="https://raw.githubusercontent.com/dynobot/OPAL-On-Raspberrypi-OS/main/apply-sys-settings.service"
DOWNLOAD_URL_APPLY_NETWORK_SETTINGS_SH="https://raw.githubusercontent.com/dynobot/OPAL-On-Raspberrypi-OS/main/apply-network-settings.sh"
DOWNLOAD_URL_NETWORK_SETTINGS_SERVICE="https://raw.githubusercontent.com/dynobot/OPAL-On-Raspberrypi-OS/main/network-settings.service"
DOWNLOAD_URL_SYSCTL_CONF="https://raw.githubusercontent.com/dynobot/OPAL-On-Raspberrypi-OS/main/99-network-tuning.conf"

BIN_DIR="/usr/local/bin"
BIN_FILE_ENDPOINT_SWITCHER="$BIN_DIR/endpoint_switcher.sh"
BIN_FILE_SOX="$BIN_DIR/sox.sh"
BIN_FILE_APPLY_SETTINGS_SH="$BIN_DIR/apply-sys-settings.sh"
BIN_FILE_APPLY_NETWORK_SETTINGS_SH="$BIN_DIR/apply-network-settings.sh"

OVERRIDE_DIR="/etc/systemd/system/squeezelite.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

SERVICE_FILE="/etc/systemd/system/apply-sys-settings.service"
NETWORK_SERVICE_FILE="/etc/systemd/system/network-settings.service"

SYSCTL_DIR="/etc/sysctl.d"
SYSCTL_CONF_FILE="$SYSCTL_DIR/99-network-tuning.conf"

ALIAS_FILE="/etc/profile.d/opal-aliases.sh"

# Text to add to cmdline.txt
CMDLINE_TEXT=" isolcpus=3 nohz_full=3"

# Text to find and replace in config.txt
AUDIO_ON="dtparam=audio=on"
AUDIO_OFF="dtparam=audio=off"

# Text to append to dtoverlay in config.txt
DTOVERLAY_OLD="dtoverlay=vc4-kms-v3d"
DTOVERLAY_NEW="dtoverlay=vc4-kms-v3d,audio=off"

# Function to download and install a file with overwrite prompt
# Args: 1=URL, 2=Destination File Path, 3="true" if executable, "false" otherwise
download_and_install_with_prompt() {
    local url="$1"
    local dest_file="$2"
    local make_executable="$3" # "true" or "false"

    local filename=$(basename "$dest_file")
    local dest_dir=$(dirname "$dest_file")

    echo "--- Handling $filename ---"
    
    # Check if the destination directory exists and create it if not needed for /etc/default (handled specifically)
    if [[ ! -d "$dest_dir" && "$dest_dir" != "/etc/default" ]]; then
        echo "Creating directory '$dest_dir'..."
        if ! sudo mkdir -p "$dest_dir"; then
            echo "Error: Failed to create directory '$dest_dir'."
            return 1
        fi
    fi

    # Check if file exists and prompt for overwrite
    if [ -f "$dest_file" ]; then
        read -p "File '$filename' already exists in '$dest_dir'. Overwrite? (y/N) " -n 1 -r REPLY
        echo # Newline for better formatting
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            echo "Skipping '$filename' download."
            return 0 # Indicate success but skipped
        fi
        echo "Overwriting '$filename'..."
    fi

    echo "Downloading file from $url..."
    if sudo wget --quiet -O "$dest_file" "$url"; then
        echo "File downloaded successfully."
        if [ "$make_executable" = "true" ]; then
            echo "Making $dest_file executable..."
            if sudo chmod +x "$dest_file"; then
                echo "File permissions updated successfully."
            else
                echo "Error: Failed to change permissions for $dest_file."
                return 1
            fi
        fi
        return 0
    else
        echo "Error: Failed to download '$filename'. Please check the URL and your internet connection."
        return 1
    fi
}

# --- Edit cmdline.txt ---
echo "--- Editing $CMDLINE_FILE ---"
if [ -f "$CMDLINE_FILE" ]; then
    if ! grep -q "$CMDLINE_TEXT" "$CMDLINE_FILE"; then
        sudo sed -i "s/$/$CMDLINE_TEXT/" "$CMDLINE_FILE"
        echo "Successfully added '$CMDLINE_TEXT' to $CMDLINE_FILE."
    else
        echo "The text '$CMDLINE_TEXT' is already in $CMDLINE_FILE. No changes made."
    fi
else
    echo "Error: The file $CMDLINE_FILE does not exist. Please check the path."
fi

echo "--------------------------------------------------------"

# --- Edit config.txt ---
echo "--- Editing $CONFIG_FILE ---"
if [ -f "$CONFIG_FILE" ]; then
    # Change dtparam=audio=on to dtparam=audio=off
    if grep -q "$AUDIO_ON" "$CONFIG_FILE"; then
        sudo sed -i "s/$AUDIO_ON/$AUDIO_OFF/" "$CONFIG_FILE"
        echo "Successfully changed '$AUDIO_ON' to '$AUDIO_OFF' in $CONFIG_FILE."
    else
        echo "The setting '$AUDIO_ON' was not found. Skipping change."
    fi

    # Change dtoverlay=vc4-kms-v3d to dtoverlay=vc4-kms-v3d,audio=off
    if grep -q "$DTOVERLAY_OLD" "$CONFIG_FILE"; then
        if ! grep -q "$DTOVERLAY_NEW" "$CONFIG_FILE"; then
            sudo sed -i "s/$DTOVERLAY_OLD/$DTOVERLAY_NEW/" "$CONFIG_FILE"
            echo "Successfully changed '$DTOVERLAY_OLD' to '$DTOVERLAY_NEW' in $CONFIG_FILE."
        else
            echo "The setting '$DTOVERLAY_NEW' is already in $CONFIG_FILE. No changes made."
        fi
    else
        echo "The setting '$DTOVERLAY_OLD' was not found. Skipping change."
    fi
else
    echo "Error: The file $CONFIG_FILE does not exist. Please check the path."
fi

echo "--------------------------------------------------------"

# --- Download and configure endpoint_switcher.sh ---
download_and_install_with_prompt "$DOWNLOAD_URL_ENDPOINT_SWITCHER" "$BIN_FILE_ENDPOINT_SWITCHER" "true"
if [ $? -ne 0 ]; then echo "Failed to process endpoint_switcher.sh. Exiting." && exit 1; fi

echo "--------------------------------------------------------"

# --- Download and configure sox.sh ---
download_and_install_with_prompt "$DOWNLOAD_URL_SOX" "$BIN_FILE_SOX" "true"
if [ $? -ne 0 ]; then echo "Failed to process sox.sh. Exiting." && exit 1; fi

echo "--------------------------------------------------------"

# --- Move and replace squeezelite file ---
echo "--- Handling squeezelite file ---"
if [ -f "$SQUEEZELITE_FILE" ]; then
    read -p "File 'squeezelite' already exists in '$SQUEEZELITE_DIR'. Overwrite? (y/N) " -n 1 -r REPLY
    echo # Newline for better formatting
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Overwriting 'squeezelite'..."
        echo "Backing up '$SQUEEZELITE_FILE' to '$SQUEEZELITE_BAK'..."
        if sudo mv "$SQUEEZELITE_FILE" "$SQUEEZELITE_BAK"; then
            echo "Backup successful."
            echo "Downloading new squeezelite file from $DOWNLOAD_URL_SQUEEZELITE..."
            if sudo wget --quiet -O "$SQUEEZELITE_FILE" "$DOWNLOAD_URL_SQUEEZELITE"; then
                echo "New file downloaded and placed successfully."
            else
                echo "Error: Failed to download the new file. Please check the URL and your internet connection."
            fi
        else
            echo "Error: Failed to back up the original squeezelite file."
        fi
    else
        echo "Skipping 'squeezelite' download and replacement."
    fi
else
    echo "The file '$SQUEEZELITE_FILE' does not exist. Downloading the new file directly."
    if sudo wget --quiet -O "$SQUEEZELITE_FILE" "$DOWNLOAD_URL_SQUEEZELITE"; then
        echo "New file downloaded and placed successfully."
    else
        echo "Error: Failed to download the new file. Please check the URL and your internet connection."
    fi
fi

echo "--------------------------------------------------------"

# --- NEW ADDITION START HERE ---
# --- Update Squeezelite name ---
echo "--- Configuring Squeezelite player name ---"

# Check if squeezelite file exists before trying to modify it
if [ -f "$SQUEEZELITE_FILE" ]; then
    # Get the current name from the file
    CURRENT_NAME=$(sudo grep -oP 'SL_NAME="\K[^|]+' "$SQUEEZELITE_FILE")

    if [ -n "$CURRENT_NAME" ]; then
        echo "Current Squeezelite name is: $CURRENT_NAME"
        read -p "Enter a new name for your player (e.g., RaspberryPi): " NEW_NAME
        
        # Check if the user entered a name
        if [ -n "$NEW_NAME" ]; then
            # Use sed to replace the old name with the new one
            sudo sed -i "s/SL_NAME=\"$CURRENT_NAME|/SL_NAME=\"$NEW_NAME|/" "$SQUEEZELITE_FILE"
            echo "Successfully updated Squeezelite name to: $NEW_NAME"
        else
            echo "No new name entered. The name will remain $CURRENT_NAME."
        fi
    else
        echo "Could not find the 'SL_NAME' line in the squeezelite file. Skipping name update."
    fi
else
    echo "Squeezelite file not found at $SQUEEZELITE_FILE. Skipping name configuration."
fi

echo "--------------------------------------------------------"
# --- NEW ADDITION ENDS HERE ---

# --- Create directory and download override.conf ---
download_and_install_with_prompt "$DOWNLOAD_URL_OVERRIDE" "$OVERRIDE_FILE" "false"
if [ $? -ne 0 ]; then echo "Failed to process override.conf. Exiting." && exit 1; fi

echo "--------------------------------------------------------"

# --- Download and configure apply-sys-settings.sh ---
download_and_install_with_prompt "$DOWNLOAD_URL_APPLY_SETTINGS_SH" "$BIN_FILE_APPLY_SETTINGS_SH" "true"
if [ $? -ne 0 ]; then echo "Failed to process apply-sys-settings.sh. Exiting." && exit 1; fi

echo "--------------------------------------------------------"

# --- Download and install systemd service file ---
download_and_install_with_prompt "$DOWNLOAD_URL_APPLY_SETTINGS_SERVICE" "$SERVICE_FILE" "false"
# Note: Enabling the service moved outside the function as it's a separate systemd command
if [ $? -eq 0 ]; then # Only enable if download/install was successful or skipped (0 means success)
    echo "Enabling the service to run at boot..."
    if sudo systemctl enable apply-sys-settings.service; then
        echo "Service enabled successfully."
    else
        echo "Error: Failed to enable the systemd service."
    fi
fi

echo "--------------------------------------------------------"

# --- Download and configure apply-network-settings.sh ---
download_and_install_with_prompt "$DOWNLOAD_URL_APPLY_NETWORK_SETTINGS_SH" "$BIN_FILE_APPLY_NETWORK_SETTINGS_SH" "true"
if [ $? -ne 0 ]; then echo "Failed to process apply-network-settings.sh. Exiting." && exit 1; fi

echo "--------------------------------------------------------"

# --- Download and install network-settings.service file ---
download_and_install_with_prompt "$DOWNLOAD_URL_NETWORK_SETTINGS_SERVICE" "$NETWORK_SERVICE_FILE" "false"
if [ $? -eq 0 ]; then
    echo "Enabling the network settings service to run at boot..."
    if sudo systemctl enable network-settings.service; then
        echo "Network service enabled successfully."
    else
        echo "Error: Failed to enable the network systemd service."
    fi
    echo "Starting the network settings service immediately..."
    if sudo systemctl start network-settings.service; then
        echo "Network service started successfully."
    else
        echo "Error: Failed to start the network systemd service."
    fi
fi

echo "--------------------------------------------------------"

# --- Download and install 99-network-tuning.conf ---
download_and_install_with_prompt "$DOWNLOAD_URL_SYSCTL_CONF" "$SYSCTL_CONF_FILE" "false"
if [ $? -eq 0 ]; then
    echo "Applying sysctl settings immediately..."
    if sudo sysctl -p "$SYSCTL_CONF_FILE"; then
        echo "Sysctl settings applied successfully."
    else
        echo "Error: Failed to apply sysctl settings. Check the file content for errors."
    fi
fi

echo "--------------------------------------------------------"

# --- Configure system-wide aliases ---
echo "--- Configuring system-wide aliases ---"

# Create the alias file if it doesn't exist
if [ ! -f "$ALIAS_FILE" ]; then
    echo "Creating alias file '$ALIAS_FILE'..."
    sudo touch "$ALIAS_FILE"
    sudo chmod 644 "$ALIAS_FILE" # Standard permissions for profile scripts
fi

# Add alias for sox.sh if it doesn't exist in the alias file
# The alias definition includes the full path to the executable script.
if ! grep -q "alias sox='${BIN_FILE_SOX}'" "$ALIAS_FILE"; then
    echo "Adding alias 'sox' for '$BIN_FILE_SOX'..."
    echo "alias sox='${BIN_FILE_SOX}'" | sudo tee -a "$ALIAS_FILE" > /dev/null
else
    echo "Alias 'sox' already exists in '$ALIAS_FILE'. Skipping."
fi

# Add alias for endpoint_switcher.sh if it doesn't exist in the alias file
# The alias definition includes the full path to the executable script.
if ! grep -q "alias endpoint='${BIN_FILE_ENDPOINT_SWITCHER}'" "$ALIAS_FILE"; then
    echo "Adding alias 'endpoint' for '$BIN_FILE_ENDPOINT_SWITCHER'..."
    echo "alias endpoint='${BIN_FILE_ENDPOINT_SWITCHER}'" | sudo tee -a "$ALIAS_FILE" > /dev/null
else
    echo "Alias 'endpoint' already exists in '$ALIAS_FILE'. Skipping."
fi

echo "Aliases configured. They will be available in new shell sessions."
echo "--------------------------------------------------------"

# --- Update systemd services ---
echo "--- Updating systemd services ---"
echo "Running 'sudo systemctl daemon-reload'..."
sudo systemctl daemon-reload
echo "Systemd daemon reloaded. All changes should now be active."
echo "Script complete."
