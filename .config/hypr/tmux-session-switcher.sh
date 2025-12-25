#!/bin/bash
session=$(tmux ls -F "#{session_name}" 2>/dev/null | wofi --dmenu -p "Select tmux session")
if [ -n "$session" ]; then
  kitty -e tmux attach -t "$session"
fi
