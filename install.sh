#!/bin/bash

USE_GUM=false
FULL_INSTALL=false
VERBOSE=false
UPDATE_OH_MY_ZSH=false

# Couleurs en variables
COLOR_BLUE="\e[38;5;33m"
COLOR_RED="\e[38;5;196m"
COLOR_RESET="\e[0m"

# Traitement des arguments en ligne de commande
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --gum|-g)
                USE_GUM=true
                ;;
            --full|-f)
                FULL_INSTALL=true
                ;;
            --update|-u)
                UPDATE_OH_MY_ZSH=true
                ;;
            --verbose|-v)
                VERBOSE=true
                ;;
            *)
                echo "Option non reconnue : $1"
                ;;
        esac
        shift
    done
}

# Appel de la fonction parse_arguments avec tous les arguments passés au script
parse_arguments "$@"

# Configuration de la redirection
if [ "$VERBOSE" = false ]; then
    redirect="> /dev/null 2>&1"
else
    redirect=""
fi

# Variables de fichiers de configuration
LOG_FILE="$HOME/omtwsl.log"

# Fonction pour afficher le banner en mode basique
bash_banner() {
    clear
    local BANNER="
╔═════════════════════════════════════╗
║                                     ║
║             OHMYTERMUXWSL           ║
║                                     ║
╚═════════════════════════════════════╝"

    echo -e "\e[38;5;33m${BANNER}$1\n\e[0m"
}

# Vérification des permissions sudo
check_sudo_permissions() {
    if ! sudo -v; then
        echo -e "\e[38;5;196mPermissions sudo requises. Veuillez exécuter le script avec sudo.\e[0m"
        exit 1
    fi
}

# Fonction pour installer gum
install_gum() {
    bash_banner
    echo -e "\e[38;5;33mInstallation de gum\e[0m"
    sudo mkdir -p /etc/apt/keyrings > /dev/null 2>&1
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg > /dev/null 2>&1
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null 2>&1
    sudo chmod 644 /etc/apt/keyrings/charm.gpg /etc/apt/sources.list.d/charm.list > /dev/null 2>&1
    sudo apt update -y > /dev/null 2>&1 && sudo apt install -y gum > /dev/null 2>&1
}

# Installation de gum si nécessaire
install_gum_if_needed() {
    if $USE_GUM; then
        if ! command -v gum &> /dev/null; then
            install_gum
        fi
    fi
}

# Fonction pour afficher le banner
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
        bash_banner
    fi
}

# Fonction pour journaliser les messages
install_log() {
    local message="$1"
    local timestamp=$(date +"%d.%m.%Y %H:%M:%S")
    local log_message="$timestamp - $message"

    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi

    echo "$log_message" >> "$LOG_FILE"
}

# Fonction pour afficher des messages d'information en bleu
info_msg() {
    local message="$1"
    if $USE_GUM; then
        gum style "${message//$'\n'/ }" --foreground 33
    else
        echo -e "\e[38;5;33m$message\e[0m"
    fi
    install_log "$message"
}

# Fonction pour afficher des messages de succès en vert
success_msg() {
    local message="$1"
    if $USE_GUM; then
        gum style "${message//$'\n'/ }" --foreground 82
    else
        echo -e "\e[38;5;82m$message\e[0m"
    fi
    install_log "$message"
}

# Fonction pour afficher des messages d'erreur en rouge
error_msg() {
    local message="$1"
    if $USE_GUM; then
        gum style "${message//$'\n'/ }" --foreground 196
    else
        echo -e "\e[38;5;196m$message\e[0m"
    fi
    install_log "$message"
}

# Fonction pour journaliser les erreurs
log_error() {
    local error_msg="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERREUR: $error_msg" >> $LOG_FILE
}

# Fonction pour exécuter une commande avec un timeout et afficher le résultat
execute_command() {
    local command="$1"
    local info_msg="$2"
    local timeout_duration="${3:-60}"
    local success_msg="✓ $info_msg"
    local error_msg="✗ $info_msg"
    local timeout_msg="⏱  $info_msg"

    if $USE_GUM; then
        if gum spin --spinner.foreground="33" --title.foreground="33" --spinner dot --title "$info_msg" -- bash -c "timeout $timeout_duration $command $redirect"; then
            gum style "$success_msg" --foreground 82
        elif [ $? -eq 124 ]; then
            gum style "$timeout_msg" --foreground 208
            log_error "Timeout: $command"
            return 1
        else
            gum style "$error_msg" --foreground 196
            log_error "$command"
            return 1
        fi
    else
        info_msg "$info_msg"
        if eval "timeout $timeout_duration $command $redirect"; then
            tput cuu1
            tput el
            success_msg "$success_msg"
        elif [ $? -eq 124 ]; then
            tput cuu1
            tput el
            echo -e "\e[38;5;208m$timeout_msg\e[0m"
            log_error "Timeout: $command"
            return 1
        else
            tput cuu1
            tput el
            error_msg "$error_msg"
            log_error "$command"
            return 1
        fi
    fi
}

# Modification de la fonction check_and_start_docker
check_and_start_docker() {
    if is_wsl; then
        if ! sudo service docker status > /dev/null 2>&1; then
            execute_command "sudo service docker start" "Démarrage du service Docker" 30
        else
            info_msg "> Le service Docker est déjà en cours d'exécution"
        fi
    else
        if ! systemctl is-active --quiet docker; then
            execute_command "sudo systemctl start docker" "Démarrage du service Docker" 30
        else
            info_msg "> Le service Docker est déjà en cours d'exécution"
        fi
    fi
}

# Fonction pour vérifier si nous sommes dans WSL
is_wsl() {
    if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
        return 0
    else
        return 1
    fi
}

check_sudo_permissions
install_gum_if_needed

show_banner

# Ajout de la vérification de la distribution
if ! command -v lsb_release &> /dev/null; then
    execute_command "sudo apt install -y lsb-release" "Installation de lsb-release"
fi

execute_command "sudo apt update -y" "Recherche de mises à jour" 30
execute_command "sudo apt upgrade -y" "Mise à jour des paquets" 180
execute_command "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common" "Installation des dépendances" 240

# Modification de l'ajout de la clé GPG Docker
execute_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -" "Ajout de la clé GPG Docker" 10

# Modification de l'ajout du dépôt Docker
execute_command "echo \"deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null" "Ajout du dépôt Docker" 20

# Mise à jour après l'ajout du dépôt
execute_command "sudo apt update" "Mise à jour des dépôts" 30

if is_wsl; then
    execute_command "sudo apt install -y docker-ce docker-ce-cli containerd.io" "Installation de Docker pour WSL" 180
    check_and_start_docker
else
    execute_command "sudo apt install -y docker-ce docker-ce-cli containerd.io" "Installation de Docker" 180
    execute_command "sudo systemctl enable docker" "Activation du service Docker" 10
    check_and_start_docker
fi

execute_command "sudo usermod -aG docker $USER" "Ajout de l'utilisateur $USER au groupe Docker" 10

# Redémarrage du service Docker
if is_wsl; then
    execute_command "sudo service docker restart" "Redémarrage du service Docker" 30
else
    execute_command "sudo systemctl restart docker" "Redémarrage du service Docker" 30
fi

#execute_command "sleep 10" "Pause de 10 secondes" 10

# Rechargement des groupes de l'utilisateur
# newgrp docker

# Lancement de Termux Docker
info_msg "Lancement de Termux Docker..."
docker run -it --rm termux/termux-docker /bin/bash

# Messages de fin
success_msg "L'installation est terminée avec succès."
info_msg "Un alias 'termux' a été ajouté à votre fichier $config_file"

# Ajout d'une pause pour l'utilisateur
read -p "Appuyez sur Entrée pour recharger la configuration du shell..."

# Rechargement de la configuration du shell
source "$config_file"

# Redémarrage du service Docker
if is_wsl; then
    execute_command "sudo service docker restart" "Redémarrage du service Docker" 30
else
    execute_command "sudo systemctl restart docker" "Redémarrage du service Docker" 30
fi

info_msg "Utiliser la commande 'termux' pour lancer Termux Docker"