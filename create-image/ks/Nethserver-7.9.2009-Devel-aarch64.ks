# Basic setup information
url --url="http://mirror.centos.org/altarch/7/os/aarch64/"
install
keyboard us --xlayouts=us --vckeymap=us
lang en_US.UTF-8
rootpw Nethesis,1234
timezone --isUtc --nontp UTC
selinux --disabled
firewall --disabled
network --device=eth0 --activate --bootproto=dhcp --onboot=on --noipv6 --hostname=localhost.localdomain
services --enabled=sshd,NetworkManager,NetworkManager-wait-online,zram-swap,nethserver-system-init 
skipx
shutdown
bootloader --location=none

# Repositories to use
repo --name="base"    --baseurl=http://mirror.centos.org/altarch/7/os/aarch64/      --cost=100
repo --name="updates" --baseurl=http://mirror.centos.org/altarch/7/updates/aarch64/ --cost=100
repo --name="extras"  --baseurl=http://mirror.centos.org/altarch/7/extras/aarch64/  --cost=100
repo --name="kernel"  --baseurl=http://mirror.centos.org/altarch/7/kernel/aarch64/kernel-generic/ --cost=100
repo --name="epel"    --baseurl=https://download-ib01.fedoraproject.org/pub/epel/7/aarch64/       --cost=100
repo --name="nethserver-base"    --baseurl=http://packages.nethserver.org/nethserver/7.9.2009/base/aarch64/    --cost=200
repo --name="nethserver-updates" --baseurl=http://packages.nethserver.org/nethserver/7.9.2009/updates/aarch64/ --cost=200
# Copr repo for epel-7-aarch64_SBC-tools owned by markvnl,
# this repo includes zram, boot-images and aarch64-img-extra-config
repo --name="sbc-tools"   --baseurl=https://copr-be.cloud.fedoraproject.org/results/markvnl/epel-7-aarch64_SBC-tools/epel-7-$basearch/ --cost=300

# Package setup
%packages --nocore
@centos-minimal
@nethserver-iso
nethserver-arm-extra-config
epel-release
aarch64-img-extra-config
bcm283x-firmware
chrony
cloud-utils-growpart
dracut-config-generic
grub2-efi
grubby
kernel
nano
net-tools
shim
uboot-images-armv8
uboot-tools
zram
-dracut-config-rescue
-ivtv*
-iwl*
-plymouth*
%end

# Disk setup
clearpart --initlabel --all 
part /boot/efi --fstype=vfat --size=256  --label=efi    --asprimary --ondisk img
part /boot     --fstype=ext4 --size=512  --label=boot   --asprimary --ondisk img
part /         --fstype=ext4 --size=3328 --label=rootfs --asprimary --ondisk img

%pre
#End of Pre script for partitions
%end


%post

## FIXME: workarounds for aarch64 {uboot,efi}-boot
echo "Setting up workarounds for aarch64 uboot-uefi..."
#
# Package aarch64-img-extra-config carries helper scripts/configs:
# - in /etc/kernel/{posttrans prerm} to let grubby update dtb-link in /boot
# - configuration in /etc/sysconfig/kernel  
# - rootfs-expand script

#
# The boot flag for 1st (fat32) efi-partion is set afterwards
#

# time-out takes much longer as 1 sec
cat > /etc/default/grub << EOF
GRUB_TIMEOUT=1
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX=""
EOF


# fix for prestine (upstream) u-boot
mv /boot/efi/EFI/BOOT/BOOTAA64.EFI /boot/efi/EFI/BOOT/BOOTAA64.org
cp -P /boot/efi/EFI/centos/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI 

# add (default disabled) Copr repo for epel-7-aarch64_SBC-tools owned by markvnl
cat > /etc/yum.repos.d/Copr_aarch64_SBC-tools.repo << EOF
# full name useful if yum-copr plugin is installed
# [copr:copr.fedorainfracloud.org:markvnl:epel-7-aarch64_SBC-tools]
# human readable name
[aarch64-sbc-tools]
name=Copr repo for epel-7-aarch64_SBC-tools owned by markvnl
baseurl=https://copr-be.cloud.fedoraproject.org/results/markvnl/epel-7-aarch64_SBC-tools/epel-7-\$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/markvnl/epel-7-aarch64_SBC-tools/pubkey.gpg
repo_gpgcheck=0
enabled=0
enabled_metadata=1

EOF

# Keep the repository enabled after system-init
cat > /etc/e-smith/templates/etc/nethserver/eorepo.conf/02 aarch64-sbc-tools << EOF
{
    #
    # 02aarch64_sbc_tools 
    # Copr repo for epel-7-aarch64_SBC-tools owned by markvnl,
    # This repo includes zram, boot-images and aarch64-img-extra-config
    # Added by ARM kickstart: do not remove it!
    #

    push @repos, 'aarch64-sbc-tools';
    
    '';
}
EOF

#
## FIXME END: workarounds for aarch64 {uboot,efi}-boot
#

echo "copy Raspberry PI3s firmware und Das Uboot..."
# firmware RPI 3(+)
echo "enter directory:"
pushd /usr/share/bcm283x-firmware/
cp -r -p overlays /boot/efi/. 
cp -p bcm2710-rpi-3-b.dtb bcm2710-rpi-3-b-plus.dtb bootcode.bin config.txt /boot/efi/.
cp -p fixup_cd.dat fixup.dat fixup_db.dat fixup_x.dat /boot/efi/.
cp -p start_cd.elf start_db.elf start.elf start_x.elf /boot/efi/.
echo "leave directory"
popd


# Uboot RPI 3(+)
cp -P /usr/share/uboot/rpi_3/u-boot.bin /boot/efi/rpi3-u-boot.bin

# Setting correct yum variable to use mainline kernel repo
echo "Setting up kernel variant..."
echo "generic" > /etc/yum/vars/kvariant


echo "Write README file..."
cat >/root/README << EOF
== Nethserver el7.8.2003 development AARCH64 image ==

Note: This is a community effort not supported by centOS by any means
      moreover at the time of this image creation epel is unmaintained!

      Please check /root/anaconda-ks.cfg on how this image came to life

      To shrink your initramfs and speed up boot, 
      you may want to remove the dracut-config-generic package
      And rebuild your intitramfs: dracut -v -f

      Have fun and debug!  


(as usual) If you want to automatically resize your / partition to use the full sd-card, 
just type the following:

rootfs-expand

EOF


# Enable heartbeat LED
echo "ledtrig-heartbeat" > /etc/modules-load.d/sbc.conf

echo "Disabeling and Masking kdump.service..."
systemctl mask kdump.service


#Nethserver-arm enable init on first boot
echo "Enabling first-boot..."
touch /var/spool/first-boot


%include ks/RPI-wifi.ks


# Remove ifcfg-link on pre generated images
rm -f /etc/sysconfig/network-scripts/ifcfg-link

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# Cleanup yum cache
yum clean all

%end

#
# Create grub config
# 

%post --nochroot
/usr/bin/mount --bind /dev $INSTALL_ROOT/dev
/usr/sbin/chroot $INSTALL_ROOT /bin/bash -c \
"/usr/sbin/grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg"
/usr/bin/umount $INSTALL_ROOT/dev

%end