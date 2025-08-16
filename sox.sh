#!/bin/bash

# Define the path to your squeezelite settings file.
# IMPORTANT: You MUST update this path to match the location of your
# 'squeezelite.conf' or equivalent settings file on your system.
# Common locations might include:
# - /etc/squeezelite/squeezelite.conf
# - /usr/local/etc/squeezelite.conf
# Based on user feedback, the correct path is /etc/default/squeezelite
SETTINGS_FILE="/etc/default/squeezelite"

# ANSI escape codes for text formatting
BOLD='\033[1m'
RESET='\033[0m'

# Ensure the script is run as root, as it needs to modify system files
# and control the squeezelite service.
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Please use 'sudo ./your_script_name.sh'." >&2
   exit 1
fi

# Define all available sound profiles and their corresponding
# SL_ADDITIONAL_OPTIONS values as an "associative array".
# The keys are the user-friendly profile names, and the values are the
# full SL_ADDITIONAL_OPTIONS string found in your settings file.
declare -A PROFILES
PROFILES["Default"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital\""
PROFILES["Hi-Fidelity"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R vXE::4:28:99:100:50\""
PROFILES["Clarity"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R v::3:28:95:100:50\""
PROFILES["Dynamic"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R v::3:28:95:100:0\""
PROFILES["Musical"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R vXE::4:28:70:110:50\""
PROFILES["Warm-Smooth"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R v::3:28:85:120:50\""
PROFILES["Warm-Punchy"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R vXE::4:28:75:120:0\""
PROFILES["Relaxed"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R v::3:28:85:120:0\""
PROFILES["Non-Oversampling"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R vE::3:28:100:100:0\""
PROFILES["Very High Quality Linear Phase"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R v::3:28:99:100:50\""
PROFILES["Very High Quality Minimum Phase"]="SL_ADDITIONAL_OPTIONS=\"-b 30720:51690 -V Digital -R v::3:28:99:100:0\""

# Ordered list of profile names for menu display and definition lookup.
# This ensures that selecting '1' always maps to "Default", '2' to "Hi-Fidelity", etc.
PROFILE_ORDER=(
    "Default"
    "Hi-Fidelity"
    "Clarity"
    "Dynamic"
    "Musical"
    "Warm-Smooth"
    "Warm-Punchy"
    "Relaxed"
    "Non-Oversampling"
    "Very High Quality Linear Phase"
    "Very High Quality Minimum Phase"
)

# Define sound profile definitions as an associative array.
# This allows for easy lookup of characteristics based on profile name.
declare -A PROFILE_DEFINITIONS
PROFILE_DEFINITIONS["Default"]="${BOLD}--- Definition for Default ---
Sound Characteristics: Default Profile
----------------------------------
Frequency Response: This profile typically represents the standard or unaltered output of Squeezelite.

Transients: Characteristics are dependent on the default internal settings of Squeezelite without any specific DSP or filtering applied.

Imaging: It aims for a neutral sound unless modified by other system-wide audio settings.

Tonality: Generally uncolored, designed to pass audio through without intentional modification.${RESET}"
PROFILE_DEFINITIONS["Hi-Fidelity"]="${BOLD}--- Definition for Hi-Fidelity ---
Sound Characteristics: Hi-Fidelity
----------------------------------
Frequency Response: Flat to 21.8 kHz—full audible range with a razor-sharp cutoff. No treble loss, maximum detail.

Transients: Very sharp; linear phase adds minor pre/post-ringing, potentially “clinical” on transients (e.g., crisp drum hits).

Imaging: Excellent—precise timing yields a wide, detailed soundstage.

Tonality: Neutral, analytical, highly detailed. Best for hi-res or complex genres (e.g., classical, jazz).${RESET}"
PROFILE_DEFINITIONS["Clarity"]="${BOLD}--- Definition for Clarity ---
Sound Characteristics: Top-Tier Clarity
----------------------------------
Frequency Response: Very flat up to 21 kHz, with a steep drop-off beyond. Preserves nearly all audible frequencies (up to 20 kHz) with minimal treble roll-off, ensuring crisp highs.

Transients: Sharp and precise due to the steep filter. You’ll hear clear, defined attacks (e.g., drum hits, plucked strings), but with some pre- and post-ringing (inaudible to most, though it can subtly “smear” transients on analytical gear).

Imaging: Excellent spatial accuracy and soundstage width, as linear phase maintains timing across frequencies. Instruments stay well-separated.

Tonality: Neutral and detailed, favoring clarity over warmth. Suits analytical listening (e.g., classical, jazz).${RESET}"
PROFILE_DEFINITIONS["Dynamic"]="${BOLD}--- Definition for Dynamic ---
Sound Characteristics: Dynamic
----------------------------------
Frequency Response: Identical to fast linear phase—flat to 21 kHz with a steep cutoff. Highs remain clear and extended.

Transients: Punchy and immediate. Minimum phase eliminates pre-ringing (echoes before transients), emphasizing the initial attack (e.g., snare drums, guitar plucks feel more “in your face”). Post-ringing remains but is less noticeable.

Imaging: Slightly less precise than linear phase due to phase shifts across frequencies, but still coherent. Soundstage might feel more “forward” than wide.

Tonality: Energetic and lively, with a focus on impact over smoothness. Suits rock, electronic, or dynamic genres.${RESET}"
PROFILE_DEFINITIONS["Musical"]="${BOLD}--- Definition for Musical ---
Sound Characteristics: Balanced and Musical
----------------------------------
Frequency Response: Rolls off from 15.4 kHz, attenuating upper treble (e.g., cymbals less sharp). Moderate transition allows minor aliasing past 20 kHz (inaudible).

Transients: Smooth with slight pre/post-ringing due to linear phase. Attacks are clear but not as sharp as steeper filters.

Imaging: Very good—linear phase preserves timing, giving a wide, accurate soundstage.

Tonality: Warmish with a relaxed top end, still detailed. Suits acoustic or vocal-heavy music.${RESET}"
PROFILE_DEFINITIONS["Warm-Smooth"]="${BOLD}--- Definition for Warm-Smooth ---
Sound Characteristics: Warm and Smooth
----------------------------------
Frequency Response: Starts rolling off earlier (around 18–19 kHz), slightly softening the uppermost treble. Still covers the audible range (up to 20 kHz), but with a gentler slope, allowing some aliasing beyond Nyquist (inaudible to most).

Transients: Smoother and less aggressive than fast roll-off. Attacks are less sharp, reducing ringing artifacts, which can make percussion or transients feel more “natural” or relaxed.

Imaging: Maintains strong soundstage and timing due to linear phase, though slightly less pinpoint than fast roll-off due to the softer filter.

Tonality: Warmer and more forgiving than fast roll-off, with a subtle reduction in treble “bite.” Great for vocals, acoustic music, or fatiguing recordings.${RESET}"
PROFILE_DEFINITIONS["Warm-Punchy"]="${BOLD}--- Definition for Warm-Punchy ---
Sound Characteristics: Warm and Punchy
----------------------------------
Frequency Response: Rolls off from 16.5 kHz, softening upper treble (e.g., cymbal shimmer reduced). Wide transition allows some aliasing past 20 kHz (inaudible).

Transients: Punchy yet smooth—no pre-ringing, with moderate post-ringing softening edges. Drums and attacks feel “natural” and forward.

Imaging: Decent but not pinpoint; minimum phase shifts timing slightly, narrowing soundstage vs. linear.

Tonality: Warm and engaging, with a relaxed treble. Good for pop, rock, or casual listening.${RESET}"
PROFILE_DEFINITIONS["Relaxed"]="${BOLD}--- Definition for Relaxed ---
Sound Characteristics: Relaxed
----------------------------------
Frequency Response: Rolls off from 18–19 kHz, softening the top end. Allows some aliasing past 20 kHz (typically inaudible).

Transients: Relaxed yet impactful. No pre-ringing, with a gentle roll-off smoothing out sharp edges—think “laid-back” drum hits or guitar strums.

Imaging: Less precise than linear phase due to phase distortion, but still musical. Soundstage feels intimate rather than expansive.

Tonality: Warmest of the bunch, with a mellow treble and natural flow. Ideal for fatigue-free listening (e.g., pop, folk, older recordings).${RESET}"
PROFILE_DEFINITIONS["Non-Oversampling"]="${BOLD}--- Definition for Non-Oversampling ---
Sound Characteristics: NOS
----------------------------------
Frequency Response: Flat to 22.05 kHz (at 44.1 kHz source), then a hard drop. No pre-Nyquist roll-off mimics NOS’s unfiltered passband, but aliasing occurs above Nyquist (e.g., 22–44 kHz mirrored back), potentially adding subtle distortion or “sheen” to highs—inaudible to most but part of the NOS charm.

Transients: Sharp and immediate, with no pre-ringing (minimum phase). Post-ringing is minimal due to the zero-width transition, giving a punchy, unprocessed feel (e.g., crisp drum hits, guitar plucks). Closer to NOS’s stair-step output than linear-phase filters.

Imaging: Decent but not precise—aliasing and phase shifts slightly blur spatial cues, narrowing soundstage vs. filtered designs. Still coherent for a “vintage” vibe.

Tonality: Warm, organic, slightly veiled highs. Midrange stands out (e.g., vocals, instruments). Less analytical, more “analog-like.”${RESET}"
PROFILE_DEFINITIONS["Very High Quality Linear Phase"]="${BOLD}--- Definition for Very High Quality Linear Phase ---
Sound Characteristics: VHQ-LPhase
----------------------------------
Frequency Response: Flat to 21.8 kHz (at 44.1 kHz), capturing the full audible range with a razor-sharp cutoff at Nyquist. No treble roll-off until the limit, ensuring maximum detail.

Transients: Extremely sharp and precise, with minimal pre/post-ringing due to the steep transition. Drum hits, plucks, and attacks are crystal-clear, though ringing might add a subtle “clinical” edge (inaudible to most).

Imaging: Outstanding—linear phase preserves timing across frequencies, delivering a wide, accurate soundstage. Instruments are perfectly placed, ideal for complex mixes.

Tonality: Neutral and transparent, with no coloration. Highs are airy, mids detailed, bass tight—textbook audiophile sound.${RESET}"
PROFILE_DEFINITIONS["Very High Quality Minimum Phase"]="${BOLD}--- Definition for Very High Quality Minimum Phase ---
Sound Characteristics: VHQ-MPhase
----------------------------------
Frequency Response: Identical to the linear phase version—flat to 21.8 kHz with a steep drop at Nyquist. Full treble extension, no early roll-off, all audible detail preserved.

Transients: Punchy and immediate—no pre-ringing, with minimal post-ringing due to the tight transition. Attacks (e.g., snare drums, guitar strums) leap out with a “live” feel, slightly less refined but more visceral than linear phase.

Imaging: Very good but slightly less precise than linear phase—minimum phase introduces phase shifts, subtly narrowing soundstage and softening spatial edges. Still highly coherent.

Tonality: Neutral with a hint of dynamism—highs are crisp, mids vibrant, bass impactful. Less analytical, more “musical” than linear phase due to the transient focus.${RESET}"

# Function to stop the squeezelite service.
stop_squeezelite() {
    echo "Stopping squeezelite..."
    # 'systemctl stop' is used to halt the service gracefully.
    systemctl stop squeezelite.service
    sleep 1 # Pause briefly to allow the service to fully stop.
}

# Function to start the squeezelite service.
start_squeezelite() {
    echo "Starting squeezelite..."
    # 'systemctl start' is used to initiate the service.
    systemctl start squeezelite.service
    sleep 1 # Pause to give squeezelite time to start.
}

# Function to apply the selected sound profile.
# This function handles updating the settings file and restarting the service.
apply_profile() {
    local profile_name="$1" # The user-friendly name of the selected profile.
    local selected_options="${PROFILES[$profile_name]}" # The full SL_ADDITIONAL_OPTIONS string for the selected profile.
    local sl_name_suffix="" # Variable to hold the suffix for SL_NAME.

    # If the profile is not "Default", append its name to SL_NAME.
    if [ "$profile_name" != "Default" ]; then
        sl_name_suffix="$profile_name"
    fi

    # Stop the squeezelite service before making changes to its configuration.
    stop_squeezelite

    echo "Applying profile: $profile_name"

    # 1. Update the SL_NAME line in the settings file to add/remove the profile suffix
    # This sed command captures the part of the SL_NAME string before the pipe '|'
    # and then replaces whatever follows the pipe (or nothing if it's just '|')
    # with the new profile suffix.
    sed -i "s/\(SL_NAME=\"[^|]*|\)[^\"P]*\"/\1${sl_name_suffix}\"/" "$SETTINGS_FILE"

    # 2. Comment out all existing SL_ADDITIONAL_OPTIONS lines that are currently uncommented.
    # This sed command works by:
    # - /regex/: Finds lines starting with 'SL_ADDITIONAL_OPTIONS='.
    # - s/^\([^#]\)/#\1/: If the line does NOT start with '#', it captures the first
    #   character (which would be 'S') and prepends '#' to it. This ensures
    #   lines are commented out without adding extra '#' if already commented.
    sed -i '/^SL_ADDITIONAL_OPTIONS=/s/^\([^#]\)/#\1/' "$SETTINGS_FILE"

    # 3. Uncomment the selected profile line.
    # First, escape any special characters in the selected_options string
    # so that 'sed' interprets it literally and correctly.
    local escaped_options=$(echo "$selected_options" | sed -e 's/[\/&]/\\&/g')
    # This sed command finds the specific line (which might be commented out)
    # and removes any leading '#' characters, effectively uncommenting it.
    sed -i "/^#*${escaped_options}/s/^#//g" "$SETTINGS_FILE"

    # Restart the squeezelite service after applying the configuration changes.
    start_squeezelite

    echo "Profile '$profile_name' applied successfully."
    display_menu # Cycle back to the main menu after applying a profile.
}

# Function to handle displaying a definition and subsequent choices.
handle_definition_view() {
    local profile_name_to_show="$1"

    # Display the definition (which now includes the BOLD/RESET codes)
    echo -e "${PROFILE_DEFINITIONS[$profile_name_to_show]}"
    echo "-----------------------------------" # Add this separator after the bolded definition
    echo "" # Add a newline for better readability.

    # Present new choices.
    echo "What would you like to do next?"
    echo "  1. Apply '$profile_name_to_show' sound profile"
    echo "  2. Show complete list of profiles"
    echo "  3. Exit"
    read -rp "Enter your choice: " next_action_choice
    echo "" # Add a newline for better readability.

    case $next_action_choice in
        1) apply_profile "$profile_name_to_show" ;;
        2) display_menu ;; # Go back to the main menu.
        3) echo "Exiting without changes. " ;;
        *) echo "Invalid choice. Please enter 1, 2, or 3. " ; handle_definition_view "$profile_name_to_show" ;; # Re-prompt for valid input.
    esac
}

# Function to display the interactive menu to the user.
display_menu() {
    local max_item_display_length=0
    # Calculate the max length for "X. ProfileName" and "XX. Exit (no change)"
    for ((idx=0; idx < ${#PROFILE_ORDER[@]}; idx++)); do
        local item_str="$((idx+1)). ${PROFILE_ORDER[idx]}"
        if (( ${#item_str} > max_item_display_length )); then
            max_item_display_length=${#item_str}
        fi
    done
    # Also check the "Exit" option
    local exit_str="$(( ${#PROFILE_ORDER[@]} + 1 )). Exit (no change)"
    if (( ${#exit_str} > max_item_display_length )); then
        max_item_display_length=${#exit_str}
    fi

    # Number of spaces between the two columns
    local inter_column_gap=4

    local menu_header="Squeezelite Sound Profile Selector "
    # Total width includes two columns (each max_item_display_length wide) + the fixed gap + initial 2 spaces
    local total_display_width=$(( (max_item_display_length * 2) + inter_column_gap + 2 ))

    # Adjust total_display_width if header is wider
    if (( ${#menu_header} + 4 > total_display_width )); then # +4 for the " = " on each side (min needed for padding)
        total_display_width=$(( ${#menu_header} + 4 ))
    fi

    # Recalculate header padding based on the potentially adjusted total_display_width
    local header_padding_len=$(( (total_display_width - ${#menu_header} - 2) / 2 )) # -2 for the spaces around header text
    local header_line_left=$(printf "%${header_padding_len}s" | tr ' ' '=')
    local header_line_right=$(printf "%$((total_display_width - ${#menu_header} - header_padding_len - 2))s" | tr ' ' '=') # -2 for spaces.

    # Print top border and header
    printf "%${total_display_width}s\n" | tr ' ' '='
    echo "${header_line_left} ${menu_header} ${header_line_right}"
    printf "%${total_display_width}s\n" | tr ' ' '='

    echo "Choose a sound profile:"

    local num_profiles=${#PROFILE_ORDER[@]}
    local profiles_per_column=$(( (num_profiles + 1) / 2 )) # Number of items per column, including Exit option

    for ((i=0; i < profiles_per_column; i++)); do
        local left_item_index=$((i + 1))
        local right_item_index=$((i + 1 + profiles_per_column))

        local left_display_str=""
        if (( left_item_index <= num_profiles )); then
            left_display_str="${left_item_index}. ${PROFILE_ORDER[left_item_index-1]}"
        fi

        local right_display_str=""
        if (( right_item_index <= num_profiles )); then
            right_display_str="${right_item_index}. ${PROFILE_ORDER[right_item_index-1]}"
        elif (( right_item_index == num_profiles + 1 )); then # This is the explicit "Exit" option
            right_display_str="${right_item_index}. Exit (no change)"
        fi

        # Print each row: 2 spaces, left column padded, inter-column gap, right column padded.
        printf "  %-*s%*s%-*s\n" \
            "$max_item_display_length" "$left_display_str" \
            "$inter_column_gap" "" \
            "$max_item_display_length" "$right_display_str"
    done

    printf "%${total_display_width}s\n" | tr ' ' '='
    read -rp "Enter your choice (e.g., '2' to apply, '2x' for definition): " choice # Prompt the user for their choice.
    echo "" # Add a newline for better readability.

    # Check if the input ends with 'x' for definition lookup.
    if [[ "$choice" =~ x$ ]]; then
        local num_choice="${choice%x}" # Remove 'x' from the choice.
        if [[ "$num_choice" =~ ^[0-9]+$ ]]; then # Ensure it's a number.
            if (( num_choice >= 1 && num_choice <= ${#PROFILE_ORDER[@]} )); then
                # Get the profile name corresponding to the numeric choice.
                local profile_name="${PROFILE_ORDER[$((num_choice - 1))]}"
                handle_definition_view "$profile_name" # Call new function to handle definition view and subsequent choices.
            else
                echo "Invalid choice for definition. Please enter a valid number from the list (e.g., '2x'). "
                display_menu # Re-display main menu after error.
            fi
        else
            echo "Invalid format for definition lookup. Please use a number followed by 'x' (e.g., '2x'). "
            display_menu # Re-display main menu after error.
        fi
        return # Exit the function after handling definition/error.
    fi

    # Handle numeric choices for applying profiles.
    if [[ "$choice" =~ ^[0-9]+$ ]]; then # Check if the input is purely numeric
        if (( choice >= 1 && choice <= ${#PROFILE_ORDER[@]} )); then
            apply_profile "${PROFILE_ORDER[$((choice - 1))]}"
        elif (( choice == ${#PROFILE_ORDER[@]} + 1 )); then # This is the Exit option
            echo "Exiting without changes. "
        else
            echo "Invalid choice. Please enter a number from the list. "
            display_menu
        fi
    else
        echo "Invalid choice. Please enter a number from the list. "
        display_menu
    fi
}

# Start the script by displaying the menu.
display_menu
