#!/bin/bash

# Définir TERM s'il n'est pas déjà défini
[ -z "$TERM" ] && export TERM=xterm

# --- Configuration ---
USE_GUM=false
FULL_INSTALL=false
UPDATE_OH_MY_ZSH=false
VERBOSE=false
LOG_FILE="$HOME/omtwsl.log"

# --- Couleurs ---
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

# --- Fonctions ---

# Affiche un message d'information
info_msg() {
    local message="ℹ  $1"
    if $USE_GUM; then
        gum style "$message" --foreground 33
    else
        echo -e "${COLOR_BLUE}$message${COLOR_RESET}"
    fi
}

# Affiche un message de succès
success_msg() {
    local message="✔ $1"
    echo -e "${COLOR_GREEN}$message${COLOR_RESET}"
    install_log "$message"
}

# Affiche un message d'erreur
error_msg() {
    local message="✗ $1"
    echo -e "${COLOR_RED}$message${COLOR_RESET}"
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
║                                  ║
║           OHMYTERMUXWSL          ║
║                                  ║
╚══════════════════════════════════╝\e[0m"
    fi
}

# Fonction pour exécuter une commande et afficher le résultat
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
            install_log "Erreur lors de l'exécution de la commande : $command"
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
            install_log "Erreur lors de l'exécution de la commande : $command"
            return 1
        fi
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

# Ajoute des alias communs au fichier de configuration du shell
add_common_alias() {
    local shell_config=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_config="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_config="$HOME/.bashrc"
    else
        error_msg "Shell non pris en charge pour l'ajout des alias communs."
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

# Modification du fichier de configuration shell
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

# Télécharge l'image Docker de Termux
download_termux_image() {
    execute_command "sudo docker pull termux/termux-docker:latest" "Téléchargement de l'image Docker Termux"
}

# Traite les arguments de ligne de commande
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

    # Vérification des droits root
    sudo -v

    # Affichage du banner
    show_banner

    # Installation des dépendances
    execute_command "sudo apt update -y" "Mise à jour des paquets"
    execute_command "sudo apt upgrade -y" "Mise à niveau des paquets"
    execute_command "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common lsb-release" "Installation des dépendances"

    # Installation de Docker
    execute_command "curl -fsSL https://get.docker.com -o get-docker.sh" "Téléchargement du script Docker"
    execute_command "sudo sh get-docker.sh" "Installation de Docker"
    execute_command "sudo usermod -aG docker $USER" "Attribution des droits nécessaires"

    # Configuration de Docker
    execute_command "sudo service docker restart" "Redémarrage du service Docker"

    # Téléchargement de l'image Termux
    download_termux_image

    # Ajout des alias communs
    add_common_alias

    # Modification du fichier de configuration shell
    modify_shell_config

    # Message de fin
    echo -e "${COLOR_BLUE}════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}⏭  Installation terminée !${COLOR_RESET}"
    info_msg "Pour démarrer, saisir : ${COLOR_YELLOW}termux${COLOR_RESET}"
    echo -e "${COLOR_BLUE}════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BLUE}Appuyez sur n'importe quelle touche...${COLOR_RESET}"
    read -r -n 1 -s
    clear
    exec $SHELL -l
}

# Appel de la fonction principale
main "$@"