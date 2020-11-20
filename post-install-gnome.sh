#!/usr/bin/env bash
set -e

sudo arch-chroot /mnt/chroot pacman --noconfirm -S gnome
sudo arch-chroot /mnt/chroot pacman --noconfirm -S gnome-tweaks
sudo arch-chroot /mnt/chroot systemctl enable gddm.service
