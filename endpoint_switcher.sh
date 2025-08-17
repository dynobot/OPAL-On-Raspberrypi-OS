#!/bin/bash

# Script to dynamically switch between Squeezelite and Roon Bridge,
# showing only the relevant options.

# Function to stop all active audio services without showing output
function stop_all_audio_services {
    sudo systemctl stop squeezelite 2>/dev/null
    sudo systemctl stop roonbridge 2>/dev/null
    sleep 1
}

# Function to disable all audio services from booting
function disable_all_audio_boot {
    # Disable roonbridge.service
    if systemctl list-unit-files --type=service | grep -q "^roonbridge.service"; then
        sudo systemctl disable roonbridge.service 2>/dev/null
    fi
    # Disable squeezelite.service (only if it's a systemd unit)
    if systemctl list-unit-files --type=service | grep -q "^squeezelite.service"; then
        sudo systemctl disable squeezelite.service 2>/dev/null
    fi
    # For legacy init.d squeezelite, ensure DAEMON_ENABLED=0 in /etc/default/squeezelite
    if [ -f "/etc/default/squeezelite" ]; then
        sudo sed -i 's/DAEMON_ENABLED=1/DAEMON_ENABLED=0/' /etc/default/squeezelite 2>/dev/null
    fi
}


# Function to ask user if they want to enable service at boot
function ask_to_enable_at_boot {
    local service_name=$1
    echo ""
    read -p "Do you want to enable $service_name to start at boot? (y/N): " enable_boot_choice
    enable_boot_choice=${enable_boot_choice:-N} # Default to No

    if [[ "$enable_boot_choice" =~ ^[Yy]$ ]]; then
        disable_all_audio_boot # First, disable everything
        
        # Now, enable only the selected service
        if [ "$service_name" == "Roon Bridge" ]; then
            sudo systemctl enable roonbridge.service 2>/dev/null
        elif [ "$service_name" == "Squeezelite" ]; then
            sudo systemctl enable squeezelite.service 2>/dev/null
            # For legacy init.d squeezelite, also ensure DAEMON_ENABLED=1 in /etc/default/squeezelite
            if [ -f "/etc/default/squeezelite" ]; then
                sudo sed -i 's/DAEMON_ENABLED=0/DAEMON_ENABLED=1/' /etc/default/squeezelite 2>/dev/null
            fi
        fi
        echo "Boot configuration updated. A reboot is recommended for changes to fully take effect."
    else
        echo "$service_name will not be enabled to start at boot."
    fi
}

# Check which service is active
CURRENT_PLAYER=""
if systemctl is-active --quiet squeezelite; then
    CURRENT_PLAYER="Squeezelite"
elif systemctl is-active --quiet roonbridge; then
    CURRENT_PLAYER="Roon Bridge"
fi

# Function to show the menu dynamically
function show_dynamic_menu {
    echo "-------------------------------------"
    if [ -n "$CURRENT_PLAYER" ]; then
        echo "    Current Player: $CURRENT_PLAYER"
    else
        echo "    No Audio Player Currently Active"
    fi
    echo "-------------------------------------"

    if [ "$CURRENT_PLAYER" == "Squeezelite" ]; then
        echo "1) Switch to Roon Bridge"
        echo "2) Exit (no change to current service)"
    elif [ "$CURRENT_PLAYER" == "Roon Bridge" ]; then
        echo "1) Switch to Squeezelite"
        echo "2) Exit (no change to current service)"
    else # No player active
        echo "1) Start Squeezelite"
        echo "2) Start Roon Bridge"
        echo "3) Exit (no change)"
    fi
    echo "-------------------------------------"
    read -p "Enter your choice: " choice
}

# Main logic
while true; do
    show_dynamic_menu

    if [ -n "$CURRENT_PLAYER" ]; then # If a player is active
        case $choice in
            1)
                stop_all_audio_services
                if [ "$CURRENT_PLAYER" == "Squeezelite" ]; then
                    sudo systemctl start roonbridge
                    if [ $? -eq 0 ]; then
                        echo "Roon Bridge is now active. Switch successful!"
                        echo "====================================="
                        ask_to_enable_at_boot "Roon Bridge"
                    else
                        echo "Error: Failed to start Roon Bridge."
                    fi
                else # Current player is Roon Bridge
                    sudo systemctl start squeezelite
                    if [ $? -eq 0 ]; then
                        echo "Squeezelite is now active. Switch successful!"
                        echo "====================================="
                        ask_to_enable_at_boot "Squeezelite"
                    else
                        echo "Error: Failed to start Squeezelite."
                    fi
                fi
                break
                ;;
            2)
                echo "Exiting without changing audio services."
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    else # No player active
        case $choice in
            1)
                stop_all_audio_services
                sudo systemctl start squeezelite
                if [ $? -eq 0 ]; then
                    echo "Squeezelite is now active. Switch successful!"
                    echo "====================================="
                    ask_to_enable_at_boot "Squeezelite"
                else
                    echo "Error: Failed to start Squeezelite."
                fi
                break
                ;;
            2)
                stop_all_audio_services
                sudo systemctl start roonbridge
                if [ $? -eq 0 ]; then
                    echo "Roon Bridge is now active. Switch successful!"
                    echo "====================================="
                    ask_to_enable_at_boot "Roon Bridge"
                else
                    echo "Error: Failed to start Roon Bridge."
                fi
                break
                ;;
            3)
                echo "Exiting without changing audio services."
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    fi
done
