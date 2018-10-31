# Basic setup information
url --url="http://mirror.centos.org/altarch/7/os/aarch64/"
install
keyboard us --xlayouts=us --vckeymap=us
lang en_US.UTF-8
rootpw centos
timezone --isUtc --nontp UTC
selinux --permissive
firewall --enabled --port=22
network --bootproto=dhcp --device=link --activate --onboot=on
services --enabled=sshd,NetworkManager,chronyd,zram-swap
skipx
shutdown
bootloader --location=mbr

# Repositories to use
repo --name="base"    --baseurl=http://mirror.centos.org/altarch/7/os/aarch64/      --cost=100
repo --name="updates" --baseurl=http://mirror.centos.org/altarch/7/updates/aarch64/ --cost=100
repo --name="extras"  --baseurl=http://mirror.centos.org/altarch/7/extras/aarch64/  --cost=100
# this repo includes the kernel
repo --name="ns-devel" --baseurl=https://mrmarkuz.goip.de/mirror/nethserver-arm/7.5.1804/devel-tools/aarch64/ --cost=100

# Package setup
%packages
@core
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
wget
zram
-dracut-config-rescue

%end

# Disk setup
clearpart --initlabel --all 
part /boot/efi --fstype=vfat --size=256  --label=boot   --asprimary --ondisk img
part /boot     --fstype=ext4 --size=768  --label=kernel --asprimary --ondisk img
part /         --fstype=ext4 --size=2560 --label=rootfs --asprimary --ondisk img

%pre
#End of Pre script for partitions
%end


%post

## FIXME workarounds for aarch64 {uboot,efi}-boot

#
# (re)configure GRUB2, does not work yet
#
# NOTE: ran manualy in chroot: /usr/sbin/grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
#
cat > /etc/default/grub << EOF
GRUB_TIMEOUT=1
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX=""

EOF

# fix u-boot's fedoraisms
# Centos uboot-images-armv8 carry Fedora patch..
cp -Pr /boot/efi/EFI/centos /boot/efi/EFI/fedora

# fix for prestine (upstream) u-boot
mv /boot/efi/EFI/BOOT/BOOTAA64.EFI /boot/efi/EFI/BOOT/BOOTAA64.org
cp -P /boot/efi/EFI/centos/grubaa64.efi boot/efi/EFI/BOOT/BOOTAA64.EFI 

# link dts to installed kernel
# NOTE: this breaks on kernel update
pushd /boot
ln -s dtb-4.18.16-201.ns7.aarch64 dtb 
popd
# Heche we disable kernel updates
cat >> /etc/yum.conf << EOF

#
## Workaround for aarch64 {uboot,efi}-boot
#
exclude=kernel*

EOF

# Raspberry PI's u-boot
cp -P /usr/share/uboot/rpi_3/u-boot.bin /boot/efi/rpi3-u-boot.bin

## FIXME end

# Enable heartbeat LED
echo "ledtrig-heartbeat" > /etc/modules-load.d/sbc.conf

# Disable / Mask kdump.service
echo "Masking kdump.service..."
systemctl mask kdump.service

# Remove ifcfg-link on pre generated images
rm -f /etc/sysconfig/network-scripts/ifcfg-link

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# Cleanup yum cache
yum clean all

%end
