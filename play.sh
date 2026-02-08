#!/bin/bash

# Save terminal settings
old_settings=$(stty -g)

# Set up terminal for game
stty -icanon -echo min 0 time 0

# Cleanup function
cleanup() {
    stty "$old_settings"
    echo
}

# Set trap to restore terminal on exit
trap cleanup EXIT INT TERM

# Run the game
./brickbuster

# Restore terminal (cleanup will also do this)
stty "$old_settings"
