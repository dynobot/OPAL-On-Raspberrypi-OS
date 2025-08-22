#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the file paths and URLs
CMDLINE_FILE="/boot/firmware/cmdline.txt"
CONFIG_FILE="/boot/firmware/config.txt"
SQUEEZELITE_DIR="/etc/default" # This directory is usually created by package manager
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

# The alias file will now be the user's .bashrc
# BASHRC_FILE will be dynamically set to the invoking user's .bashrc
BASHRC_FILE=""

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
    
    # Check if the destination directory exists and create it if not.
    # mkdir -p is idempotent, so it's safe to run even if the directory exists.
    if ! sudo mkdir -p "$dest_dir"; then
        echo "Error: Failed to create directory '$dest_dir'."
        return 1
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

# --- Main Script Execution ---

echo "Starting system configuration script..."
echo "--------------------------------------------------------"

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
    # Fail early if a critical file is missing.
    exit 1 
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
    # Fail early if a critical file is missing.
    exit 1
fi

echo "--------------------------------------------------------"

# --- Download and configure endpoint_switcher.sh ---
if ! download_and_install_with_prompt "$DOWNLOAD_URL_ENDPOINT_SWITCHER" "$BIN_FILE_ENDPOINT_SWITCHER" "true"; then
    echo "Failed to process endpoint_switcher.sh. Exiting."
    exit 1
fi

echo "--------------------------------------------------------"

# --- Download and configure sox.sh ---
if ! download_and_install_with_prompt "$DOWNLOAD_URL_SOX" "$BIN_FILE_SOX" "true"; then
    echo "Failed to process sox.sh. Exiting."
    exit 1
fi

echo "--------------------------------------------------------"

# --- Handle squeezelite file ---
echo "--- Handling squeezelite file ($SQUEEZELITE_FILE) ---"
# Ensure the squeezelite config directory exists
if ! sudo mkdir -p "$SQUEEZELITE_DIR"; then
    echo "Error: Failed to create directory '$SQUEEZELITE_DIR'."
    exit 1
fi

if [ -f "$SQUEEZELITE_FILE" ]; then
    read -p "File 'squeezelite' already exists in '$SQUEEZELITE_DIR'. Overwrite and backup? (y/N) " -n 1 -r REPLY
    echo # Newline for better formatting
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Overwriting 'squeezelite'..."
        echo "Backing up '$SQUEEZELITE_FILE' to '$SQUEEZELITE_BAK'..."
        # Attempt to backup; if it fails, exit.
        if ! sudo mv "$SQUEEZELITE_FILE" "$SQUEEZELITE_BAK"; then
            echo "Error: Failed to back up the original squeezelite file. Aborting replacement."
            exit 1 # Exit on critical backup failure
        fi
        echo "Backup successful."
        echo "Downloading new squeezelite file from $DOWNLOAD_URL_SQUEEZELITE..."
        # Attempt to download; if it fails, restore backup and exit.
        if ! sudo wget --quiet -O "$SQUEEZELITE_FILE" "$DOWNLOAD_URL_SQUEEZELITE"; then
            echo "Error: Failed to download the new file. Attempting to restore backup."
            sudo mv "$SQUEEZELITE_BAK" "$SQUEEZELITE_FILE" # Attempt to restore backup
            echo "Backup restored."
            exit 1 # Exit on critical download failure
        fi
        echo "New file downloaded and placed successfully."
    else
        echo "Skipping 'squeezelite' download and replacement."
    fi
else
    echo "The file '$SQUEEZELITE_FILE' does not exist. Downloading the new file directly."
    # Attempt to download directly if file doesn't exist; if it fails, exit.
    if ! sudo wget --quiet -O "$SQUEEZELITE_FILE" "$DOWNLOAD_URL_SQUEEZELITE"; then
        echo "Error: Failed to download the new file. Please check the URL and your internet connection."
        exit 1 # Exit on critical download failure
    fi
    echo "New file downloaded and placed successfully."
fi

echo "--------------------------------------------------------"

# --- Configure Squeezelite player name ---
echo "--- Configuring Squeezelite player name ---"

if [ -f "$SQUEEZELITE_FILE" ]; then
    # Extract the base name (e.g., "OPAL" from "SL_NAME="OPAL|Clarity" or "SL_NAME="OPAL")
    # This regex looks for SL_NAME=" followed by any characters that are NOT a pipe or closing quote.
    # Using '|| true' to prevent set -e from exiting if grep finds no match.
    BASE_NAME=$(sudo grep -oP 'SL_NAME="\K[^|"\]+' "$SQUEEZELITE_FILE" || true)

    if [ -n "$BASE_NAME" ]; then
        echo "Current Squeezelite base name is: $BASE_NAME"
        read -p "Enter a new base name for your player (e.g., RPi-Player, leave blank to keep '$BASE_NAME'): " NEW_BASE_NAME_INPUT
        # If user provides a new name, use it; otherwise, stick to the existing base name.
        NEW_BASE_NAME="${NEW_BASE_NAME_INPUT:-$BASE_NAME}"

        echo "The player's name will be updated to: ${NEW_BASE_NAME}|<profile_name_suffix>"
        echo "This only sets the base name. The profile suffix will be applied when you select a sound profile."
        
        # Now update the SL_NAME line in the file to reflect the new base name.
        # It handles both cases: SL_NAME="BASE|" and SL_NAME="BASE|SUFFIX"
        # It replaces the entire SL_NAME line to ensure a clean update.
        if ! sudo sed -i "s/^SL_NAME=\"[^|]*|.*\"/SL_NAME=\"${NEW_BASE_NAME}|\"/" "$SQUEEZELITE_FILE"; then
            echo "Error: Failed to update Squeezelite base name with sed."
            exit 1
        fi
        echo "Successfully updated Squeezelite base name to: ${NEW_BASE_NAME}|"
    else
        # If SL_NAME line exists but doesn't match the pattern (e.g., SL_NAME="")
        # Or if the line doesn't exist at all, BASE_NAME will be empty.
        # Let's check for the existence of SL_NAME= in general
        if grep -q "^SL_NAME=" "$SQUEEZELITE_FILE"; then
            echo "Found 'SL_NAME=' line, but its format is unexpected. Attempting to set a default base name."
            read -p "Enter a new base name for your player (e.g., RPi-Player, default 'OPAL'): " NEW_BASE_NAME_INPUT
            NEW_BASE_NAME="${NEW_BASE_NAME_INPUT:-OPAL}"
            if ! sudo sed -i "s/^SL_NAME=.*$/SL_NAME=\"${NEW_BASE_NAME}|\"/" "$SQUEEZELITE_FILE"; then
                echo "Error: Failed to initialize Squeezelite base name with sed."
                exit 1
            fi
            echo "Successfully initialized Squeezelite base name to: ${NEW_BASE_NAME}|"
        else
            echo "Could not find any 'SL_NAME=' line in the squeezelite file. Skipping name update."
            echo "You may need to manually add 'SL_NAME=\"OPAL|\"' to $SQUEEZELITE_FILE."
        fi
    fi
else
    echo "Squeezelite file not found at $SQUEEZELITE_FILE. Skipping name configuration."
fi

echo "--------------------------------------------------------"

# --- Create directory and download override.conf ---
if ! download_and_install_with_prompt "$DOWNLOAD_URL_OVERRIDE" "$OVERRIDE_FILE" "false"; then
    echo "Failed to process override.conf. Exiting."
    exit 1
fi

echo "--------------------------------------------------------"

# --- Download and configure apply-sys-settings.sh ---
if ! download_and_install_with_prompt "$DOWNLOAD_URL_APPLY_SETTINGS_SH" "$BIN_FILE_APPLY_SETTINGS_SH" "true"; then
    echo "Failed to process apply-sys-settings.sh. Exiting."
    exit 1
fi

echo "--------------------------------------------------------"

# --- Download and install systemd service file (apply-sys-settings) ---
if ! download_and_install_with_prompt "$DOWNLOAD_URL_APPLY_SETTINGS_SERVICE" "$SERVICE_FILE" "false"; then
    echo "Failed to process apply-sys-settings.service. Exiting."
    exit 1
fi
echo "Enabling the apply-sys-settings.service to run at boot..."
if ! sudo systemctl enable apply-sys-settings.service; then
    echo "Error: Failed to enable 'apply-sys-settings.service'. Please check systemd logs."
    exit 1 # Exit on critical service enable failure
fi

echo "--------------------------------------------------------"

# --- Download and configure apply-network-settings.sh ---
if ! download_and_install_with_prompt "$DOWNLOAD_URL_APPLY_NETWORK_SETTINGS_SH" "$BIN_FILE_APPLY_NETWORK_SETTINGS_SH" "true"; then
    echo "Failed to process apply-network-settings.sh. Exiting."
    exit 1
fi

echo "--------------------------------------------------------"

# --- Download and install network-settings.service file ---
if ! download_and_install_with_prompt "$DOWNLOAD_URL_NETWORK_SETTINGS_SERVICE" "$NETWORK_SERVICE_FILE" "false"; then
    echo "Failed to process network-settings.service. Exiting."
    exit 1
fi

echo "Enabling the network-settings.service to run at boot..."
if ! sudo systemctl enable network-settings.service; then
    echo "Error: Failed to enable 'network-settings.service'. Please check systemd logs."
    exit 1 # Exit on critical service enable failure
fi
echo "Starting the network settings service immediately..."
if ! sudo systemctl start network-settings.service; then
    echo "Error: Failed to start 'network-settings.service'. Please check systemd logs."
    exit 1 # Exit on critical service start failure
fi

echo "--------------------------------------------------------"

# --- Download and install 99-network-tuning.conf ---
if ! download_and_install_with_prompt "$DOWNLOAD_URL_SYSCTL_CONF" "$SYSCTL_CONF_FILE" "false"; then
    echo "Failed to process 99-network-tuning.conf. Exiting."
    exit 1
fi
echo "Applying sysctl settings immediately..."
if ! sudo sysctl -p "$SYSCTL_CONF_FILE"; then
    echo "Error: Failed to apply sysctl settings. Check the file content for errors."
    exit 1 # Exit on critical sysctl failure
fi

echo "--------------------------------------------------------"

# --- Configure user aliases in ~/.bashrc ---
echo "--- Configuring user aliases ---"

# Determine the correct .bashrc file for the invoking user
if [ -n "$SUDO_USER" ]; then
    TARGET_USER_HOME="/home/$SUDO_USER"
    # Ensure the home directory exists before attempting to write to it
    if [ ! -d "$TARGET_USER_HOME" ]; then
        echo "Warning: Home directory for user '$SUDO_USER' does not exist. Creating it."
        if ! sudo mkdir -p "$TARGET_USER_HOME"; then
            echo "Error: Failed to create home directory '$TARGET_USER_HOME'. Cannot configure aliases."
            exit 1
        fi
        if ! sudo chown "$SUDO_USER":"$SUDO_USER" "$TARGET_USER_HOME"; then
            echo "Error: Failed to set ownership for '$TARGET_USER_HOME'."
            exit 1
        fi
    fi
    BASHRC_FILE="$TARGET_USER_HOME/.bashrc"
    echo "Targeting user '$SUDO_USER's .bashrc at: $BASHRC_FILE"
else
    # Fallback if SUDO_USER is not set (e.g., script run directly as root)
    BASHRC_FILE="$HOME/.bashrc" # This will be /root/.bashrc if run as root
    echo "Warning: SUDO_USER not set. Aliases will be added to $BASHRC_FILE (likely /root/.bashrc)."
    echo "If you intend these for a different user, please run the script with 'sudo ./script.sh'."
fi

# Check if the .bashrc file exists, if not, create it
if [ ! -f "$BASHRC_FILE" ]; then
    echo "Creating .bashrc file '$BASHRC_FILE'..."
    if [ -n "$SUDO_USER" ]; then
        if ! sudo -u "$SUDO_USER" touch "$BASHRC_FILE"; then
            echo "Error: Failed to create .bashrc for user '$SUDO_USER'."
            exit 1
        fi
    else
        if ! sudo touch "$BASHRC_FILE"; then # For /root/.bashrc
            echo "Error: Failed to create .bashrc in root's home."
            exit 1
        fi
    fi
fi

# Alias for sox.sh
ALIAS_SOX="alias sox='${BIN_FILE_SOX}'"
if ! grep -qxF "$ALIAS_SOX" "$BASHRC_FILE"; then
    echo "Adding alias 'sox' to '$BASHRC_FILE'..."
    if [ -n "$SUDO_USER" ]; then
        if ! sudo -u "$SUDO_USER" sh -c "echo '$ALIAS_SOX' >> \"$BASHRC_FILE\""; then
            echo "Error: Failed to add alias 'sox' to '$BASHRC_FILE'."
            exit 1
        fi
    else
        if ! sudo sh -c "echo '$ALIAS_SOX' >> \"$BASHRC_FILE\""; then
            echo "Error: Failed to add alias 'sox' to '$BASHRC_FILE'."
            exit 1
        fi
    fi
else
    echo "Alias 'sox' already exists in '$BASHRC_FILE'. Skipping."
fi

# Alias for endpoint_switcher.sh
ALIAS_ENDPOINT="alias endpoint='${BIN_FILE_ENDPOINT_SWITCHER}'"
if ! grep -qxF "$ALIAS_ENDPOINT" "$BASHRC_FILE"; then
    echo "Adding alias 'endpoint' to '$BASHRC_FILE'..."
    if [ -n "$SUDO_USER" ]; then
        if ! sudo -u "$SUDO_USER" sh -c "echo '$ALIAS_ENDPOINT' >> \"$BASHRC_FILE\""; then
            echo "Error: Failed to add alias 'endpoint' to '$BASHRC_FILE'."
            exit 1
        fi
    else
        if ! sudo sh -c "echo '$ALIAS_ENDPOINT' >> \"$BASHRC_FILE\""; then
            echo "Error: Failed to add alias 'endpoint' to '$BASHRC_FILE'."
            exit 1
        fi
    fi
else
    echo "Alias 'endpoint' already exists in '$BASHRC_FILE'. Skipping."
fi

echo "Aliases configured in '$BASHRC_FILE'. They will be available in new shell sessions."
echo "To apply them immediately in your current session, run: source $BASHRC_FILE"
echo "--------------------------------------------------------"

# --- Update systemd services ---
echo "--- Updating systemd services ---"
echo "Running 'sudo systemctl daemon-reload'..."
if ! sudo systemctl daemon-reload; then
    echo "Error: Failed to reload systemd daemon. Some service changes might not take effect."
    exit 1
fi
echo "Systemd daemon reloaded. All changes should now be active."
echo "Script complete."
