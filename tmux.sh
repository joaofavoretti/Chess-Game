#!/usr/bin/env bash

# Start a tmux session named 'dev'
tmux new-session -d -s dev

# Rename the window to 'editor' and start nvim in the src directory
tmux rename-window -t dev:0 'editor'
tmux send-keys -t dev:0 'cd src; nvim .' C-m

# Split the window horizontally and start a terminal in the src directory
tmux split-window -v -t dev:0 -p 10

# Attach to the tmux session
tmux attach-session -t dev
