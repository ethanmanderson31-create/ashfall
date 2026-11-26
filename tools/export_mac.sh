#!/bin/zsh
# Rebuilds Ashfall.app and installs it to ~/Applications.
set -e
cd "$(dirname "$0")/.."
GODOT=~/Applications/Godot.app/Contents/MacOS/Godot
rm -rf build/Ashfall.app
$GODOT --headless --path . --export-release "macOS" build/Ashfall.app
rm -rf ~/Applications/Ashfall.app
cp -R build/Ashfall.app ~/Applications/
echo "Installed ~/Applications/Ashfall.app"
