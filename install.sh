#!/bin/bash

# Set TERM if not already defined
[ -z "$TERM" ] && export TERM=xterm

# --- Configuration ---
USE_GUM=false
FULL_INSTALL=false
UPDATE_OH_MY_ZSH=false
VERBOSE=false
LOG_FILE="$HOME/omtwsl.log"

# --- Colors ---
COLOR_BLUE="\e[38;5;33m"
COLOR_RED="\e[38;5;196m"
COLOR_GREEN="\e[38;5;82m"
COLOR_YELLOW="\e[38;5;208m"
COLOR_RESET="\e[0m"

# --- Redirection ---
redirect_output() {
    if [ "$VERBOSE" = false ]; then
        "$@" > /dev/null 2>&1
    else
        "$@"
    fi
}

# --- Functions ---

# Display an information message
info_msg() {
    local message="ℹ  $1"
    if $USE_GUM; then
        gum style "$message" --foreground 33
    else
        echo -e "${COLOR_BLUE}$message${COLOR_RESET}"
    fi
}

# Display a success message
success_msg() {
    local message="✔ $1"
    echo -e "${COLOR_GREEN}$message${COLOR_RESET}"
    install_log "$message"
}

# Display an error message
error_msg() {
    local message="✗ $1"
    echo -e "${COLOR_RED}$message${COLOR_RESET}"
    install_log "$message"
}

# Log a message
install_log() {
    local message="$1"
    local timestamp=$(date +"%d.%m.%Y %H:%M:%S")
    echo "$timestamp - $message" >> "$LOG_FILE"
}

# Check if gum is installed and offer to install it
check_gum() {
    if $USE_GUM && ! command -v gum &> /dev/null; then
        read -r -p "gum is required but not installed. Do you want to install it? [Y/n] " response
        case "$response" in
            [yY][eE][sS]|[yY]|"") 
                install_gum
                ;;
            *)
                echo "gum not installed. Some features will be disabled."
                USE_GUM=false
                ;;
        esac
    fi
}

# Install gum
install_gum() {
    info_msg "Installing gum..."
    sudo mkdir -p /etc/apt/keyrings > /dev/null 2>&1
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg > /dev/null 2>&1
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null 2>&1
    sudo chmod 644 /etc/apt/keyrings/charm.gpg /etc/apt/sources.list.d/charm.list > /dev/null 2>&1
    sudo apt update -y > /dev/null 2>&1 && sudo apt install -y gum > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        success_msg "gum installed successfully."
    else
        error_msg "Error installing gum."
    fi
}

# Display the banner
show_banner() {
    clear
    if $USE_GUM; then
        # Display banner with gum
        gum style \
            --foreground 33 \
            --border-foreground 33 \
            --border double \
            --align center \
            --width 35 \
            --margin "1 1 1 0" \
            "" "OHMYTERMUXWSL" ""
    else
        # Display banner in text mode
        echo -e "\e[38;5;33m
╔══════════════════════════════════╗
║                                  ║
║           OHMYTERMUXWSL          ║
║                                  ║
╚══════════════════════════════════╝\e[0m"
    fi
}

# Function to execute a command and display the result
execute_command() {
    local command=" $1"
    local info_msg=" $2"
    local success_msg=" $2"
    local error_msg=" $2"

    if $USE_GUM; then
        if gum spin --spinner.foreground="33" --title.foreground="33" --spinner dot --title "$info_msg" -- bash -c "redirect_output $command"; then
            gum style "$success_msg" --foreground 82
        else
            gum style "$error_msg" --foreground 196
            install_log "Error executing command: $command"
            return 1
        fi
    else
        info_msg "$2"
        if redirect_output $command; then
            tput cuu1
            tput el
            success_msg "$success_msg"
        else
            tput cuu1
            tput el
            error_msg "$error_msg"
            install_log "Error executing command: $command"
            return 1
        fi
    fi
}

# Check if we're in WSL
is_wsl() {
    if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
        return 0
    else
        return 1
    fi
}

# Add common aliases to the shell configuration file
add_common_alias() {
    local shell_config=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_config="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_config="$HOME/.bashrc"
    else
        error_msg "Unsupported shell for adding common aliases."
        return 1
    fi

    local common_aliases="
# Common aliases

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias h='history'
alias q='exit'
alias c='clear'
alias md='mkdir'
alias rm='rm -rf'
alias s='source'
alias n='nano'
alias bashrc='nano \$HOME/.bashrc'
alias zshrc='nano \$HOME/.zshrc'
alias cm='chmod +x'
alias g='git'
alias gc='git clone'
alias push='git pull && git add . && git commit -m \"mobile push\" && git push'

"

    if ! grep -q "# Common aliases" "$shell_config"; then
        echo -e "\n$common_aliases" >> "$shell_config"
    fi
}

# Modify shell configuration file
modify_shell_config() {
    local shell_config=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_config="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_config="$HOME/.bashrc"
    else
        error_msg "Shell non pris en charge pour l'ajout de l'alias."
        return 1
    fi

    if ! grep -q "alias termux=" "$shell_config"; then
        echo "alias termux='sudo docker run -it --rm termux/termux-docker /bin/bash'" >> "$shell_config"
    fi
    if ! grep -q "export TERM=xterm" "$shell_config"; then
        echo 'export TERM=xterm' >> $shell_config
    fi
}

# Download Termux Docker image
download_termux_image() {
    execute_command "sudo docker pull termux/termux-docker:latest" "Downloading Termux Docker image"
}

# Process command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                VERBOSE=true
                ;;
            --gum|-g)
                USE_GUM=true
                ;;
            *)
                error_msg "Unrecognized option: $1"
                exit 1
                ;;
        esac
        shift
    done
}

# --- Main function ---
main() {
    # Process arguments
    parse_arguments "$@"

    # Check for gum
    check_gum

    # Check for root rights
    sudo -v

    # Display banner
    show_banner

    # Install dependencies
    execute_command "sudo apt update -y" "Updating packages"
    execute_command "sudo apt upgrade -y" "Upgrading packages"
    execute_command "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common lsb-release" "Installing dependencies"

    # Install Docker
    execute_command "curl -fsSL https://get.docker.com -o get-docker.sh" "Downloading Docker script"
    execute_command "sudo sh get-docker.sh" "Installing Docker"
    execute_command "sudo usermod -aG docker $USER" "Granting necessary permissions"

    # Configure Docker
    execute_command "sudo service docker restart" "Restarting Docker service"

    # Download Termux image
    download_termux_image

    # Add common aliases
    add_common_alias

    # Modify shell configuration file
    modify_shell_config

    # End message
    echo -e "${COLOR_BLUE}════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}⏭  Installation complete!${COLOR_RESET}"
    info_msg "To start, type: ${COLOR_YELLOW}termux${COLOR_RESET}"
    echo -e "${COLOR_BLUE}════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BLUE}Press any key...${COLOR_RESET}"
    read -r -n 1 -s
    clear
    exec $SHELL -l
}

# Call the main function
main "$@"
