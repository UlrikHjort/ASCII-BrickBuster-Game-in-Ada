#!/bin/bash

echo "Building BrickBuster..."
gnatmake brickbuster.adb

if [ $? -eq 0 ]; then
    echo "Build successful! Run ./play.sh to play."
else
    echo "Build failed!"
    exit 1
fi
