#!/bin/bash

sudo pacman -S --needed git base-devel fuse2

if [ ! -d "caido-desktop" ]; then
    git clone https://aur.archlinux.org/caido-desktop.git
fi

cd caido-desktop
makepkg -si

