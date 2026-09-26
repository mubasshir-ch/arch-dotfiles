#!/bin/bash

# Your specific hardware names
KB_NAME="at-translated-set-2-keyboard"
TP_NAME="elan1301:00-04f3:3115-touchpad"

# Listen for the tablet-mode switch event
libinput debug-events | grep --line-buffered "switch tablet-mode" | while read -r line; do
    if [[ "$line" == *"state 1"* ]]; then
        # Tablet mode active: Disable physical inputs
        hyprctl keyword device:$KB_NAME:enabled false
        hyprctl keyword device:$TP_NAME:enabled false
    elif [[ "$line" == *"state 0"* ]]; then
        # Laptop mode active: Enable physical inputs
        hyprctl keyword device:$KB_NAME:enabled true
        hyprctl keyword device:$TP_NAME:enabled true
    fi
done
