#!/bin/bash

tmux start-server

if ! tmux has-session 2>/dev/null; then
    tmux new-session -d -s main
fi

tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh

# Optional: attach to session
# tmux attach-session -t main
