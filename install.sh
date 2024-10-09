#!/bin/bash

# --- Configuration ---
USE_GUM=false
FULL_INSTALL=false
UPDATE_OH_MY_ZSH=false
VERBOSE=false
LOG_FILE="$HOME/omtwsl.log"
# Supprimé : TIMEOUT_DURATION=60 # Timeout par défaut en secondes

# --- Couleurs ---
COLOR_BLUE="\e[38;5;33m"
COLOR_RED="\e[38;5;196m"
COLOR_GREEN="\e[38;5;82m"
COLOR_YELLOW="\e[38;5;208m"
COLOR_RESET="\e[0m"

# --- Fonctions ---

# Affiche un message d'information
info_msg() {
    local message="$1"
    echo -e "${COLOR_BLUE}$message${COLOR_RESET}"
    install_log "$message"
}

# Affiche un message de succès
success_msg() {
    local message="$1"
    echo -e "${COLOR_GREEN}✓ $message${COLOR_RESET}"
    install_log "$message"
}

# Affiche un message d'erreur
error_msg() {
    local message="$1"
    echo -e "${COLOR_RED}✗ $message${COLOR_RESET}"
    install_log "$message"
}

# Journalise un message
install_log() {
    local message="$1"
    local timestamp=$(date +"%d.%m.%Y %H:%M:%S")
    echo "$timestamp - $message" >> "$LOG_FILE"
}

# Vérifie si gum est installé et propose de l'installer
check_gum() {
    if $USE_GUM && ! command -v gum &> /dev/null; then
        read -r -p "gum est requis mais non installé. Voulez-vous l'installer ? [O/n] " response
        case "$response" in
            [oO][uUiI]*|"") 
                install_gum
                ;;
            *)
                echo "gum non installé. Certaines fonctionnalités seront désactivées."
                USE_GUM=false
                ;;
        esac
    fi
}

# Installe gum
install_gum() {
    info_msg "Installation de gum..."
    sudo mkdir -p /etc/apt/keyrings > /dev/null 2>&1
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg > /dev/null 2>&1
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null 2>&1
    sudo chmod 644 /etc/apt/keyrings/charm.gpg /etc/apt/sources.list.d/charm.list > /dev/null 2>&1
    sudo apt update -y > /dev/null 2>&1 && sudo apt install -y gum > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        success_msg "gum installé avec succès."
    else
        error_msg "Erreur lors de l'installation de gum."
    fi
}

# Affiche le banner
show_banner() {
    clear
    if $USE_GUM; then
        # Afficher le banner avec gum
        gum style \
            --foreground 33 \
            --border-foreground 33 \
            --border double \
            --align center \
            --width 35 \
            --margin "1 1 1 0" \
            "" "OHMYTERMUXWSL" ""
    else
        # Afficher le banner en mode texte
        echo -e "\e[38;5;33m
╔══════════════════════════════════╗
║                                     ║
║             OHMYTERMUXWSL           ║
║                                     ║
╚══════════════════════════════════╝\e[0m"
    fi
}

# Vérifie les permissions sudo
check_sudo_permissions() {
    if ! sudo -v; then
        error_msg "Permissions sudo requises. Veuillez exécuter le script avec sudo."
        exit 1
    fi
}

# Exécute une commande et affiche le résultat
execute_command() {
    local command="$1"
    local message="$2"

    info_msg "$message..."
    if bash -c "$command" > /dev/null 2>&1; then
        success_msg "$message"
    else
        error_msg "$message"
        return 1
    fi
}

# Vérifie si on est dans WSL
is_wsl() {
    if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
        return 0
    else
        return 1
    fi
}

# Vérifie et démarre Docker
check_and_start_docker() {
    if is_wsl; then
        if ! sudo service docker status > /dev/null 2>&1; then
            execute_command "sudo service docker start" "Démarrage du service Docker" 30
        else
            info_msg "Le service Docker est déjà en cours d'exécution."
        fi
    else
        if ! systemctl is-active --quiet docker; then
            execute_command "sudo systemctl start docker" "Démarrage du service Docker" 30
        else
            info_msg "Le service Docker est déjà en cours d'exécution."
        fi
    fi
}

# Ajoute l'alias Termux au fichier de configuration du shell
add_termux_alias() {
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
        echo "echo \"Pour lancer Termux Docker, exécutez la commande 'termux'\"" >> "$shell_config"
        success_msg "Alias 'termux' ajouté à $shell_config"
    else
        info_msg "L'alias 'termux' existe déjà dans $shell_config"
    fi

    echo "$shell_config"  # Retourne le chemin du fichier de configuration
}

# Traite les arguments de ligne de commande
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full|-f)
                FULL_INSTALL=true
                ;;
            --update-omz|-u)
                UPDATE_OH_MY_ZSH=true
                ;;
            --verbose|-v)
                VERBOSE=true
                ;;
            --gum|-g)
                USE_GUM=true
                ;;
            *)
                error_msg "Option non reconnue : $1"
                exit 1
                ;;
        esac
        shift
    done
}

# --- Fonction principale ---
main() {
    # Traitement des arguments
    parse_arguments "$@"

    # Vérification de gum
    check_gum

    # Vérification des permissions sudo
    check_sudo_permissions

    # Affichage du banner
    show_banner

    # Installation des dépendances
    execute_command "sudo apt update -y" "Mise à jour des paquets"
    execute_command "sudo apt upgrade -y" "Mise à niveau des paquets"
    execute_command "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common lsb-release" "Installation des dépendances"

    # Installation de Docker
    execute_command "curl -fsSL https://get.docker.com -o get-docker.sh" "Téléchargement du script d'installation Docker"
    execute_command "sudo sh get-docker.sh" "Installation de Docker"
    execute_command "sudo usermod -aG docker $USER" "Ajout de l'utilisateur au groupe docker"

    # Configuration de Docker
    check_and_start_docker
    execute_command "sudo service docker restart" "Redémarrage du service Docker"

    # Ajout de l'alias Termux au fichier de configuration du shell
    shell_config=$(add_termux_alias)

    # Fin du script
    success_msg "Installation terminée avec succès."
    info_msg "L'alias 'termux' a été ajouté à votre configuration shell."

    if [ -n "$shell_config" ]; then
        info_msg "Application des modifications..."
        eval "source $shell_config"
        success_msg "Les modifications ont été appliquées. Vous pouvez maintenant utiliser la commande 'termux'."
    else
        error_msg "Impossible d'appliquer les modifications. Veuillez redémarrer votre terminal."
    fi
}

# Appel de la fonction principale
main "$@"
