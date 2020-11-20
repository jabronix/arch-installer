#!/usr/bin/env bash
set -e

subvols=("@var @srv @opt @tmp @usr-local @snapshots @var-cache-pacman-pkg")

[ -z "$desktop" ] && desktop='none'

sudo mkdir /mnt/btrfs
btrfsonluks=$(sudo blkid -o device | grep luks)
sudo mount -o subvolid=5 "$btrfsonluks" /mnt/btrfs

sudo sed -i 's/compress=zstd 0 1/compress=zstd 0 0/' /mnt/btrfs/@/etc/fstab
sudo sed -i 's/compress=zstd 0 2/compress=zstd 0 0/' /mnt/btrfs/@/etc/fstab

cp /root/.cache/calamares/session.log /mnt/btrfs/@/var/log/calamares.log

templstr=$(grep "/home" /mnt/btrfs/@/etc/fstab)

for subvol in "${subvols[@]}"
do
    if [ "$subvol" = "@snapshots" ]; then
        svpath="/.snapshots"
    else
        svpath=${subvol//@/\/}
        svpath=${svpath//-/\/}
    fi

    sudo btrfs subvolume create "/mnt/btrfs/${subvol}"
    [ -d "/mnt/btrfs/@${svpath}" ] && cp -R "/mnt/btrfs/@${svpath}/." "/mnt/btrfs/${subvol}" && rm -rf "/mnt/btrfs/@${svpath}"

    fstabstr=${templstr//\/home/${svpath}}
    fstabstr=${fstabstr//@home/${subvol}}
    sudo sh -c "echo $fstabstr >> /mnt/btrfs/@/etc/fstab"
done

[ -z "$swapsize" ] && export swapsize=8G 
if [ $swapsize = "0" ] || [ $swapsize = "0G" ] || [ $swapsize = "none" ]; then
    sudo btrfs subvolume create /mnt/btrfs/@swap
    sudo mkdir /mnt/btrfs/@/swap
    sudo sh -c "printf '\n$btrfsonluks /swap          btrfs   subvol=@swap,defaults,compress=no 0 0\n' >> /mnt/btrfs/@/etc/fstab"
    sudo truncate -s 0 /mnt/btrfs/@swap/swapfile
    sudo chattr +C /mnt/btrfs/@swap/swapfile
    sudo btrfs property set /mnt/btrfs/@swap/swapfile compression none
    sudo fallocate -l "$swapsize" /mnt/btrfs/@swap/swapfile
    sudo chmod 600 /mnt/btrfs/@swap/swapfile
    sudo mkswap /mnt/btrfs/@swap/swapfile
    sudo swapon /mnt/btrfs/@swap/swapfile
    sudo sh -c "echo '/swap/swapfile none swap defaults 0 0' >> /mnt/btrfs/@/etc/fstab"
    wget https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
    gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
    offset=$(sudo ./btrfs_map_physical /mnt/btrfs/@swap/swapfile)
    offset_arr=("${offset}")
    offset_pagesize=("$(getconf PAGESIZE)")
    offset=$(( offset_arr[25] / offset_pagesize ))
    sudo sed -i "s/loglevel=3/loglevel=3 resume_offset=$offset/" /mnt/btrfs/@/etc/default/grub
    sudo sed -i "s#loglevel=3#resume=$btrfsonluks loglevel=3#" /mnt/btrfs/@/etc/default/grub
    sudo sed -i 's/keymap encrypt filesystems/keymap encrypt filesystems resume/' /mnt/btrfs/@/etc/mkinitcpio.conf

fi

sudo mount -o compress=zstd,subvol=@,x-mount.mkdir "$btrfsonluks" /mnt/chroot
sudo mount -o compress=zstd,subvol=@home,x-mount.mkdir "$btrfsonluks" /mnt/chroot/home

for volmount in "${subvols[@]}"
do
    sudo mount -o compress=zstd,subvol="${volmount}",x-mount.mkdir "$btrfsonluks" "/mnt/chroot${${volmount//@/\/}//-/\/}"
done

efidevice=$(sudo blkid -o device -l -t TYPE=vfat)
sudo mount "$efidevice" /mnt/chroot/boot/efi
sudo arch-chroot /mnt/chroot pacman --noconfirm -S cronie
sudo arch-chroot /mnt/chroot systemctl enable cronie.service
sudo arch-chroot /mnt/chroot grub-mkconfig -o /boot/grub/grub.cfg
sudo arch-chroot /mnt/chroot mkinitcpio -p linux

[ $desktop = "none" ] && echo "No desktop requested.  Finished." && exit 0

./post-install-${desktop}.sh
