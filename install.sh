#!/bin/bash
set -euo pipefail

CC_DIR="$HOME/.classic-counter"
STEAM_DIR="$HOME/.local/share/Steam"

export PROTON_DIR="$CC_DIR/proton"
export PROTON="$PROTON_DIR/proton"

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_DIR"
export STEAM_COMPAT_APP_ID=0
export STEAM_COMPAT_DATA_PATH="$CC_DIR/compatdata"
export STEAM_COMPAT_INSTALL_PATH="$CC_DIR"
export STEAM_COMPAT_LIBRARY_PATHS="$STEAM_DIR/steamapps"
export STEAM_COMPAT_MOUNTS="$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper"
export STEAM_COMPAT_TOOL_PATHS="$PROTON_DIR:$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper"

export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"


# ===============================
# Messages
# ===============================

print_error() {
    local msg=$1
    echo -e "\033[31m[ERROR]: $msg\033[0m"
}

print_success() {
    local msg=$1
    echo -e "\033[32m[SUCCESS]: $msg\033[0m"
}

print_info() {
    local msg=$1
    echo -e "\033[0m[INFO]: $msg\033[0m"
}


# ===============================
# Checks
# ===============================

check_steam() {
    print_info "Checking if ~/.steam exists..."
    if [ ! -d "$STEAM_DIR" ]; then
        print_error "Steam not found! Maybe you're using flatpak version? Install Steam or reinstall Steam with your native package manager."
        exit 1
    fi
    print_success "Steam was found."
}

check_compat_tool_paths() {
    print_info "Checking if SteamLinuxRuntime_sniper exists..."
    if [ ! -d "$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper" ]; then
        print_error "File not found! Install SteamLinuxRuntime_sniper! Exiting..."
        exit 1
    fi
    print_success "File was found."
}

check_dependencies() {
    print_info "Checking required dependencies..."
    local deps=("curl" "jq" "wget" "tar" "awk" "winetricks" "sha256sum" "sha512sum")
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required commands: ${missing[*]}"
        print_error "Please install them via your package manager."
        exit 1
    fi
    print_success "All dependencies are installed."
}

do_checks() {
    check_steam
    check_compat_tool_paths
    
    check_dependencies
}

# ===============================
# Installation functions
# ===============================

download_wauncher() {
    curl -sSf "https://api.github.com/repos/ClassicCounter/launcher/releases/latest" \
        > wauncher_release.json

    WAUNCHER_URL=$(jq -r '.assets[0].browser_download_url' wauncher_release.json)
    WAUNCHER_HASH=$(jq -r '.assets[0].digest' wauncher_release.json | sed 's/sha256://')
    WAUNCHER_FILENAME=$(jq -r '.assets[0].name' wauncher_release.json)
    
    # Check for valid json structure or API errors
    if [ -z "$WAUNCHER_URL" ] || [ "$WAUNCHER_URL" = "null" ]; then
        print_error "wauncher.exe: could not determine download URL from GitHub API response."
        exit 1
    fi

    wget -N "$WAUNCHER_URL"

    # Hash validation
    if [ -n "$WAUNCHER_HASH" ] && [ "$WAUNCHER_HASH" != "null" ]; then
        if ! echo "$WAUNCHER_HASH  $WAUNCHER_FILENAME" | sha256sum -c -; then
            print_error "wauncher.exe: Checksum mismatch! File may be corrupted."
            rm -f "$WAUNCHER_FILENAME"
            exit 1
        fi
        print_success "wauncher.exe: Checksum verification successful."
    else
        print_error "wauncher.exe: Checksum not found in release API or API returned null."
        exit 1
    fi

    rm wauncher_release.json
}

download_proton() {
    # Hardcoded Proton-GE version that works fine with Classic-Counter 
    PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.tar.gz"
    PROTON_HASH_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.sha512sum"
    PROTON_FILENAME="proton.tar.gz"

    wget -O "$PROTON_FILENAME" "$PROTON_URL"
    wget -O "$PROTON_FILENAME.sha512sum" "$PROTON_HASH_URL"

    HASH_VAL=$(awk '{print $1}' "$PROTON_FILENAME.sha512sum")

    # Hash validation
    if ! echo "$HASH_VAL  $PROTON_FILENAME" | sha512sum -c -; then
        print_error "proton.tar.gz: Checksum mismatch! File may be corrupted."
        rm -f "$PROTON_FILENAME" "$PROTON_FILENAME.sha512sum"
        exit 1
    fi
    print_success "proton.tar.gz: Checksum verification successful."
    rm -f "$PROTON_FILENAME.sha512sum"

    mkdir -p "$PROTON_DIR"
    tar -xf proton.tar.gz --strip-components=1 -C "$PROTON_DIR"
    rm proton.tar.gz
}

init_prefix() {
    mkdir -p "$STEAM_COMPAT_DATA_PATH"

    # Starting "wineserver -w" to prevent winetricks running while prefix is still creating
    "$PROTON" run wineboot
    "$PROTON_DIR/files/bin/wineserver" -w

    winetricks -q \
        dotnet8 vcrun2017 
}

generate_launch_script() {
    cat << 'EOF' > "$CC_DIR/launch.sh"
#!/bin/bash
CC_DIR="$HOME/.classic-counter"

STEAM_DIR="$HOME/.local/share/Steam"
RUNTIME="$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point"

export PROTON_DIR="$CC_DIR/proton"
export PROTON="$PROTON_DIR/proton"
export PROTON_WINE="$PROTON_DIR/files/bin/wine"

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_DIR"
export STEAM_COMPAT_APP_ID=0
export STEAM_COMPAT_DATA_PATH="$CC_DIR/compatdata"
export STEAM_COMPAT_INSTALL_PATH="$CC_DIR"
export STEAM_COMPAT_LIBRARY_PATHS="$STEAM_DIR/steamapps"
export STEAM_COMPAT_MOUNTS="$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper"
export STEAM_COMPAT_TOOL_PATHS="$PROTON_DIR:$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper"
export SteamAppId=730
export SteamGameId=730

start_game() {
    exec "$RUNTIME" \
        --verb=waitforexitandrun \
        -- \
        "$PROTON" waitforexitandrun \
        "$CC_DIR/wauncher.exe"
}

start_game
EOF

    chmod +x "$CC_DIR/launch.sh"
}

generate_desktop_file() {
    cat << 'EOF' > "$CC_DIR/classic-counter.desktop"
[Desktop Entry]
Type=Application
Name=Classic-Counter
Comment=Launch Classic Counter
Exec=bash -c 'exec "$HOME/.classic-counter/launch.sh"'
Path=%h/.classic-counter
Icon=applications-games
Terminal=false
Categories=Game;
EOF

    chmod +x "$CC_DIR/classic-counter.desktop"
}

link_desktop_file() {
    mkdir -p "$HOME/.local/share/applications"
    ln -sf "$CC_DIR/classic-counter.desktop" "$HOME/.local/share/applications/classic-counter.desktop"
}

install() {
    mkdir -p "$CC_DIR" && cd "$CC_DIR"
    download_wauncher
    download_proton
    init_prefix
    generate_launch_script
    generate_desktop_file
    link_desktop_file
}


# ===============================
# Main
# ===============================

main() {
    do_checks
    install
}
main
