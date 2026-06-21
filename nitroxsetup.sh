#!/usr/bin/env bash
set -euo pipefail

# Config
dotnet_required_min_version="9.0"
dotnet_install_path="$HOME/.dotnet/" 
nitrox_launcher_file_name="Nitrox.Launcher"
nitrox_server_file_name="Nitrox.Server.Subnautica"
nitrox_download_folder_name="Nitrox_GitHub_Download"
nitrox_install_path="$HOME/.Nitrox/" 
nitrox_temp_install_path="/tmp/Nitrox Setup Files $(date +%s)/"
nitrox_desktop_file="$HOME/Desktop/NitroxLauncher.desktop"

# Color Config
SUCCESS="$(tput setaf 2)[SUCCESS]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 3)[WARN]$(tput sgr0)"
RED="$(tput setaf 1)"
ORANGE="$(tput setaf 214)"
WARNING="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

# Functions
prompt_confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [${GREEN}y${RESET}/${RED}N${RESET}]: " REPLY
    case $REPLY in
        [yY]) echo ; return 0 ;;
        *) echo ; return 1 ;;
    esac 
  done  
}

nitrox_ensure_execute_flag() {
    check_target_file_path="${nitrox_install_path}$1"
    [ -f "${check_target_file_path}" ] || { echo "${ERROR} Nitrox installation failed. Missing file: '${check_target_file_path}'"; return 1; }

    echo "${INFO} Checking if $1 has executable permissions..."    
    if [ -x "$check_target_file_path" ]; then
        echo "${SUCCESS} $1 has executable permissions!"
    else
        echo "${WARN} $1 does not have executable permissions!"
        echo "${INFO} Adding executable permissions automatically....."
        chmod +x "$check_target_file_path"
    fi
}

nitrox_add_desktop_file() {
    prompt_confirm "${SKY_BLUE} Do you wish to add a desktop shortcut for Nitrox? ${RESET}" || return 0
    
    if [ -f "$nitrox_desktop_file" ]; then
        echo "${WARN} A desktop shortcut for Nitrox already exists!"
        return 0
    fi
    
    # Check if the nitrox icon does NOT exist and if it doesn't download the nitrox icon from github and place it in the Nitrox directory.
    if [ ! -f "$nitrox_install_path/nitrox-icon.png" ]; then
        echo "${INFO} Downloading the icon image of Nitrox from the repository..."    
        curl https://raw.githubusercontent.com/SubnauticaNitrox/Nitrox/refs/heads/master/Nitrox.Launcher/Assets/Images/nitrox-icon.ico -o "$nitrox_install_path/nitrox-icon.png"
    fi

    cat <<EOF > "$nitrox_desktop_file"
    [Desktop Entry]
    Name=Nitrox Launcher
    Comment=A open-source, multiplayer modification for the game Subnautica.
    Exec=$(get_dotnet_binary) $nitrox_install_path${nitrox_launcher_file_name}.dll
    Icon=${nitrox_install_path}nitrox-icon.png
    Type=Application
    Terminal=false
    Categories=Game
EOF

   chmod +x "$nitrox_desktop_file"
   
   # Copy the desktop file in the "applications" directory so Nitrox can be accessed from the application menu as well.
   cp "$nitrox_desktop_file" "$HOME/.local/share/applications/"

   echo "${SUCCESS} A desktop shortcut has been created!"
}

get_nitrox_latest_download_url() {
    nitrox_target_arch=$(uname -m)
    if [ "$nitrox_target_arch" == "x86_64" ]; then
        nitrox_target_arch="x64"
    elif [ "$nitrox_target_arch" == "aarch64" ]; then
        nitrox_target_arch="arm64"
    fi
    curl -s https://api.github.com/repos/SubnauticaNitrox/Nitrox/releases/latest \
    | awk -v arch="linux_$nitrox_target_arch" -F'"' '
      /browser_download_url/ && $0 ~ arch {
        print $4
        exit
      }
    '
}

get_dotnet_binary() {
    if [ -f "$HOME/.dotnet/dotnet" ]; then
        echo "$HOME/.dotnet/dotnet"
        return 0
    fi    
    echo "dotnet"
}

nitrox_install() {
    if [ -f "$nitrox_install_path$nitrox_launcher_file_name" ]; then
        prompt_confirm "${SKY_BLUE} Delete existing Nitrox installation? ${RESET}" || return 0
        rm -rf "$nitrox_install_path"
    fi
    echo "${INFO} Downloading latest Nitrox Linux release..."
    curl -L -o "$nitrox_zip_file_path" "$(get_nitrox_latest_download_url)"
    echo "${INFO} Extracting all contents..."
    unzip -o "$nitrox_zip_file_path" -d "$nitrox_install_path" 
    nitrox_ensure_execute_flag "${nitrox_launcher_file_name}"
    nitrox_ensure_execute_flag "${nitrox_server_file_name}"
}

dotnet_install() {
    echo "${INFO} Checking if .NET Runtime ${dotnet_required_min_version} is installed..."

    if $(get_dotnet_binary) --list-runtimes 2>/dev/null | grep -q "Microsoft.NETCore.App $dotnet_required_min_version"; then
        echo "${SUCCESS} .NET Runtime is available!"
        return 0
    fi

    echo "${WARN} Minimum required .NET Runtime ${dotnet_required_min_version} is not installed!"
    prompt_confirm "${SKY_BLUE} Do you wish to install the latest .NET Runtime? ${RESET}" || { echo "${INFO} .NET Runtime install cancelled."; return 0; }
    echo "${INFO} Installing latest .NET Runtime..."
    curl -L https://dot.net/v1/dotnet-install.sh -o "${nitrox_temp_install_path}dotnet-install.sh"
    chmod +x "${nitrox_temp_install_path}/dotnet-install.sh"
    "${nitrox_temp_install_path}dotnet-install.sh" --version latest --runtime dotnet --channel "$dotnet_required_min_version" --install-dir "$dotnet_install_path"
}

# Computed variables
nitrox_zip_file_name="${nitrox_download_folder_name}.zip"
nitrox_zip_file_path="${nitrox_temp_install_path}${nitrox_zip_file_name}"


# Program
echo "${BLUE} ----------------Nitrox-Setup-Script-1.8.1.0----------------- ${RESET}"
mkdir "${nitrox_temp_install_path}"
dotnet_install
nitrox_install
nitrox_add_desktop_file
echo "${SUCCESS} Done."

# Helpful info
dotnet_binary=$(get_dotnet_binary)
echo
echo "Start the Launcher directly with:"
echo "${GREEN} $dotnet_binary ${nitrox_install_path}${nitrox_launcher_file_name}.dll ${RESET}"
echo "Start the Server directly with:"
echo "${GREEN} $dotnet_binary ${nitrox_install_path}${nitrox_server_file_name}.dll ${RESET}"
