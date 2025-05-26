#!/bin/bash

SESSION_NAME="minecraft_server"
SERVER_DIR="/home/fickle/minecraft"

if screen -list | grep -q "$SESSION_NAME"; then
    echo "Minecraft server is already running in screen session '$SESSION_NAME'."
    exit 1
fi

# Start the server in a detached screen session
screen -dmS "$SESSION_NAME" bash -c "cd $SERVER_DIR; java -jar /home/fickle/minecraft/server.jar; read -p 'press enter'"
echo "Minecraft server started in screen session '$SESSION_NAME'."
echo "Type \`screen -r $SESSION_NAME\` to attach."
echo "Type \`ctrl + a\`, then \`d\` to detach."
