#!/bin/bash

# Check if the virtual keyboard is running
if pgrep -x "wvkbd-mobintl" > /dev/null; then
    # If running, kill it
    pkill -x "wvkbd-mobintl"
else
    # If not running, launch it at the bottom of the screen
    # -L 300 sets the height to 300px. 
    # --hidden means it starts out of sight and slides up
    wvkbd-mobintl -L 300 &
fi
