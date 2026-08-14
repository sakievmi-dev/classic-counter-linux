#!/bin/bash
CC_DIR="$HOME/.classic-counter"
STEAM_DIR="$HOME/.local/share/Steam"

WAUNCHER_URL="https://github.com/ClassicCounter/launcher/releases/download/3.2.6/wauncher.exe"
PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.tar.gz"

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
# Installation functions
# ===============================

download_wauncher() {
    wget -N $WAUNCHER_URL
}

download_proton() {
    wget -O proton.tar.gz $PROTON_URL
    mkdir -p $PROTON_DIR
    tar -xf proton.tar.gz --strip-components=1 -C $PROTON_DIR
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
    mkdir -p $CC_DIR && cd $CC_DIR
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
    install
}
main
