#!/bin/bash

# Path to the Minecraft server screen session
SCREEN_NAME="minecraft_server"

if curl -s -f http://169.254.169.254/latest/meta-data/spot/instance-action > /dev/null; then
    echo "Spot instance interruption notice received at $(date)"
    screen -S "$SCREEN_NAME" -X stuff "say Spot instance terminating in 2 minutes! Server saving...^M"
    screen -S minecraft_server -X stuff "save-all flush^M"
    exit 0
fi
