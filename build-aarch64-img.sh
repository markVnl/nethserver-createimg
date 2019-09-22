#!/bin/bash
ks="$1"

if [ -z "$1" ] ;then
  echo $0 path/to/file.ks
  exit 1
fi

img=$(echo $ks|rev|cut -f 1 -d "/"|rev|sed s/\.ks//g)

time appliance-creator --config=${ks} --name="$img" --version="7" --debug --no-compress

if [[ $? -ne 0 ]]; then
   exit $?
fi

chown -R $(logname). $img


#
# FIXME
#

# hack to configure grub2
losetup -f -P ${img}/$img-img.raw
if [[ $? -ne 0 ]]; then
   echo -e "\nFailed to finalize aarch64 image!\n"
   exit $?
fi
loopdev=$(losetup | grep $img | awk 'END{print $1}')

tmp=`/bin/mktemp -d --suffix aarch64-img`

echo -e "\n\nRemounting image attached to $loopdev on $tmp ..."
mount ${loopdev}p3 ${tmp}
mount ${loopdev}p2 ${tmp}/boot
mount ${loopdev}p1 ${tmp}/boot/efi
mount --bind /proc ${tmp}/proc
mount --bind /dev  ${tmp}/dev
mount --bind /sys  ${tmp}/sys

chroot ${tmp} /bin/bash -c "/usr/sbin/grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg"

echo "Umounting image from $tmp and detaching ${loopdev} ..."
umount -R ${tmp}
losetup -d ${loopdev}
rm -rf ${tmp}

echo "Setting 1st (EFI) as boot partition..."
( echo a ; echo 1 ; echo w )  | sudo fdisk  ${img}/$img-img.raw > /dev/null 2>&1
( echo a ; echo 2 ; echo w )  | sudo fdisk  ${img}/$img-img.raw > /dev/null 2>&1

echo -e "done\n"

#
# END FIXME
#
