#!/usr/bin/env bash
set -e

sudo arch-chroot /mnt/chroot pacman --noconfirm -S kde
sudo arch-chroot /mnt/chroot pacman --noconfirm -S kde-system-meta kde-system-utilities
sudo arch-chroot /mnt/chroot systemctl enable gddm.service
