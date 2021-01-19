# Basic setup information
install
keyboard us --xlayouts=us --vckeymap=us
rootpw Nethesis,1234
timezone --isUtc --nontp UTC
selinux --disabled
firewall --disabled
#On armhfp we are pretty sure network defaults to eth0
network --device=eth0 --activate --bootproto=dhcp --onboot=on --noipv6 --hostname=localhost.localdomain
services --enabled=sshd,NetworkManager,NetworkManager-wait-online,zram-swap,nethserver-system-init 
shutdown
bootloader --location=mbr  --extlinux
lang en_US.UTF-8

# Repositories to use
repo --name="base"          --baseurl=http://mirror.centos.org/altarch/7/os/armhfp/      --cost=100
repo --name="updates"       --baseurl=http://mirror.centos.org/altarch/7/updates/armhfp/ --cost=100
repo --name="extras"        --baseurl=http://mirror.centos.org/altarch/7/extras/armhfp/  --cost=100
repo --name="centos-kernel" --baseurl=http://mirror.centos.org/altarch/7/kernel/armhfp/kernel-generic/  --cost=100
repo --name="nethserver-base"    --baseurl=http://packages.nethserver.org/nethserver/7.9.2009/base/armhfp/    --cost=100
repo --name="nethserver-updates" --baseurl=http://packages.nethserver.org/nethserver/7.9.2009/updates/armhfp/ --cost=100
# epel-pass1
repo --name="epel"               --baseurl=https://armv7.dev.centos.org/repodir/epel-pass-1/ --cost=100


# Disk setup
clearpart --initlabel --all
part /boot --fstype=ext4 --size=768  --label=boot   --asprimary --ondisk img
part /     --fstype=ext4 --size=2560 --label=rootfs --asprimary --ondisk img

# Package setup
%packages  --nocore
@centos-minimal
@nethserver-iso
nethserver-arm-epel
chrony
cloud-utils-growpart
dracut-config-extradrivers
dracut-config-generic
extlinux-bootloader
grubby
kernel
net-tools
uboot-images-armv7
zram
-dracut-config-rescue
-kernel-headers
%end


%pre

#End of Pre script for partitions
%end


%post

# Remove legacy _uImage_ and _uInitrd_ kernel copy's
echo "Removing uImage and uInitrd kernel copy's"
rm -f /boot/uI*

# Setting correct yum variable to use mainline kernel repo
echo "Setting up kernel variant..."
echo "generic" > /etc/yum/vars/kvariant

# Disable / Mask kdump.service
echo "Masking kdump.service..."
systemctl mask kdump.service


# On armhfp we are pretty sure wireless network interface defaults to wlan0
# Configure wpa_supplicant to control wlan0 
echo "Configuring wpa_supplicant..."
sed -i 's/INTERFACES=""/INTERFACES="-iwlan0"/' /etc/sysconfig/wpa_supplicant

# Mandatory README file
echo "Write README file..."
cat >/root/README << EOF
== Nethserver 7 userland ==

If you want to automatically resize your / partition, just type the following (as root user):
rootfs-expand

EOF


#Nethserver-arm enable init on first boot
echo "Enabling first-boot..."
touch /var/spool/first-boot

%include ks/Uboot-wifi.ks

# Remove ifcfg-link on pre generated images
rm -f /etc/sysconfig/network-scripts/ifcfg-link

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# Cleanup yum cache
yum clean all

%end
