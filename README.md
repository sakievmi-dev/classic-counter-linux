# classic-counter-linux
Script for installing Classic-Counter launcher on linux. Automatically downloads Proton-GE, creates wine prefix and includes a wrapper script for launcher.

> [!WARNING]
> This script only was tested on Arch Linux

## Installation
### 1. Install dependencies
#### Arch Linux (or Steam Deck)
```shell
sudo pacman -S steam wget winetricks jq
```

### 2. Run this script
```shell
curl -sSL https://raw.githubusercontent.com/sakievmi-dev/classic-counter-linux/refs/heads/main/install.sh | bash
```

### 3. Done!
You can run your Classic-Counter launcher through terminal:
```shell
~/.classic-counter/launch.sh
```

Or through your application launcher. Script adds .desktop file to `~/.local/share/applications`.
