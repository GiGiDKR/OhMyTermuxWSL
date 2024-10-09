#!/bin/bash

# --- Configuration ---
USE_GUM=false
FULL_INSTALL=false
UPDATE_OH_MY_ZSH=false
VERBOSE=false
LOG_FILE="$HOME/omtwsl.log"
TIMEOUT_DURATION=60 # Timeout par défaut en secondes

# --- Couleurs ---
COLOR_BLUE="\e[38;5;33m"
COLOR_RED="\e[38;5;196m"
COLOR_GREEN="\e[38;5;82m"
COLOR_YELLOW="\e[38;5;208m"
COLOR_RESET="\e[0m"

# --- Fonctions ---

log_message() {
    local level="$1"
    local message="$2"
    local color=""
    local symbol=""

    case "$level" in
        "INFO") color="$COLOR_BLUE"; symbol="ℹ" ;;
        "SUCCESS") color="$COLOR_GREEN"; symbol="✓" ;;
        "ERROR") color="$COLOR_RED"; symbol="✗" ;;
        "TIMEOUT") color="$COLOR_YELLOW"; symbol="⏱" ;;
    esac

    echo -e "${color}${symbol} $message${COLOR_RESET}"
    install_log "$level: $message"
}

install_log() {
    local message="$1"
    local timestamp=$(date +"%d.%m.%Y %H:%M:%S")
    echo "$timestamp - $message" >> "$LOG_FILE"
}

check_and_install_gum() {
    if $USE_GUM && ! command -v gum &> /dev/null; then
        if confirm "gum est requis mais non installé. Voulez-vous l'installer ?"; then
            install_gum
        else
            log_message "INFO" "gum non installé. Certaines fonctionnalités seront désactivées."
            USE_GUM=false
        fi
    fi
}

install_gum() {
    log_message "INFO" "Installation de gum..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo chmod 644 /etc/apt/keyrings/charm.gpg /etc/apt/sources.list.d/charm.list
    if sudo apt update -y && sudo apt install -y gum; then
        log_message "SUCCESS" "gum installé avec succès."
    else
        log_message "ERROR" "Erreur lors de l'installation de gum."
    fi
}

show_banner() {
    clear
    if $USE_GUM; then
        gum style \
            --foreground 33 \
            --border-foreground 33 \
            --border double \
            --align center \
            --width 35 \
            --margin "1 1 1 0" \
            "" "OHMYTERMUXWSL" ""
    else
        echo -e "\e[38;5;33m
╔══════════════════════════════════╗
║                                  ║
║           OHMYTERMUXWSL          ║
║                                  ║
╚══════════════════════════════════╝\e[0m"
    fi
}

check_sudo_permissions() {
    if ! sudo -v; then
        log_message "ERROR" "Permissions sudo requises. Veuillez exécuter le script avec sudo."
        exit 1
    fi
}

execute_command() {
    local command="$1"
    local message="$2"
    local timeout="${3:-$TIMEOUT_DURATION}"

    log_message "INFO" "$message..."
    if timeout $timeout bash -c "$command" > /dev/null 2>&1; then
        log_message "SUCCESS" "$message"
    elif [ $? -eq 124 ]; then
        log_message "TIMEOUT" "$message"
        return 1
    else
        log_message "ERROR" "$message"
        return 1
    fi
}

is_wsl() {
    [ -f /proc/version ] && grep -qi microsoft /proc/version
}

check_and_start_docker() {
    if is_wsl; then
        if ! sudo service docker status > /dev/null 2>&1; then
            execute_command "sudo service docker start" "Démarrage du service Docker" 30
        else
            log_message "INFO" "Le service Docker est déjà en cours d'exécution."
        fi
    else
        if ! systemctl is-active --quiet docker; then
            execute_command "sudo systemctl start docker" "Démarrage du service Docker" 30
        else
            log_message "INFO" "Le service Docker est déjà en cours d'exécution."
        fi
    fi
}

add_termux_alias() {
    local shell_config=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_config="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_config="$HOME/.bashrc"
    else
        log_message "ERROR" "Shell non pris en charge pour l'ajout de l'alias."
        return 1
    fi

    if ! grep -q "alias termux=" "$shell_config"; then
        echo "alias termux='sudo docker run -it --rm termux/termux-docker /bin/bash'" >> "$shell_config"
        echo "echo \"Pour lancer Termux Docker, exécutez la commande 'termux'\"" >> "$shell_config"
        log_message "SUCCESS" "Alias 'termux' ajouté à $shell_config"
    else
        log_message "INFO" "L'alias 'termux' existe déjà dans $shell_config"
    fi

    echo "$shell_config"
}

confirm() {
    local message="$1"
    if $USE_GUM; then
        gum confirm "$message"
    else
        read -r -p "$message [O/n] " response
        case "$response" in
            [oO][uUiI]*|"") return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# --- Script principal ---

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --gum|-g) USE_GUM=true ;;
            --full|-f) FULL_INSTALL=true ;;
            --update|-u) UPDATE_OH_MY_ZSH=true ;;
            --verbose|-v) VERBOSE=true ;;
            *) echo "Option non reconnue : $1" ;;
        esac
        shift
    done
}

main() {
    parse_arguments "$@"
    check_and_install_gum
    check_sudo_permissions
    show_banner

    execute_command "sudo apt update -y" "Mise à jour des paquets" 30
    execute_command "sudo apt upgrade -y" "Mise à niveau des paquets" 180
    execute_command "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common lsb-release" "Installation des dépendances" 240

    execute_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg" "Ajout de la clé GPG Docker" 10
    execute_command "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null" "Ajout du dépôt Docker" 10
    execute_command "sudo apt update" "Mise à jour des dépôts" 30

    if is_wsl; then
        execute_command "sudo apt install -y docker-ce docker-ce-cli containerd.io" "Installation de Docker pour WSL" 180
    else
        execute_command "sudo apt install -y docker-ce docker-ce-cli containerd.io" "Installation de Docker" 180
        execute_command "sudo systemctl enable docker" "Activation du service Docker" 10
    fi

    check_and_start_docker
    execute_command "sudo usermod -aG docker $USER" "Ajout de l'utilisateur au groupe Docker" 10
    execute_command "sudo service docker restart" "Redémarrage du service Docker" 30

    shell_config=$(add_termux_alias)

    log_message "SUCCESS" "Installation terminée avec succès."
    log_message "INFO" "L'alias 'termux' a été ajouté à votre configuration shell."

    if [ -n "$shell_config" ]; then
        log_message "INFO" "Application des modifications..."
        eval "source $shell_config"
        log_message "SUCCESS" "Les modifications ont été appliquées. Vous pouvez maintenant utiliser la commande 'termux'."
    else
        log_message "ERROR" "Impossible d'appliquer les modifications. Veuillez redémarrer votre terminal."
    fi
}

main "$@"