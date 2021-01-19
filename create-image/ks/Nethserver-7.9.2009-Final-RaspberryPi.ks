
# Basic setup information
install
keyboard us --xlayouts=us --vckeymap=us
rootpw Nethesis,1234
timezone --isUtc --nontp UTC
selinux --disabled
firewall --disabled
#On a raspbery Pi we are pretty sure network defaults to eth0
network --device=eth0 --activate --bootproto=dhcp --onboot=on --noipv6 --hostname=localhost.localdomain
services --enabled=sshd,NetworkManager,NetworkManager-wait-online,zram-swap,nethserver-system-init 
lang en_US.UTF-8

# Repositories to use
repo --name="base"          --baseurl=http://mirror.centos.org/altarch/7/os/armhfp/      --cost=100
repo --name="updates"       --baseurl=http://mirror.centos.org/altarch/7/updates/armhfp/ --cost=100
repo --name="extras"        --baseurl=http://mirror.centos.org/altarch/7/extras/armhfp/  --cost=100

# Local build kernel fixed zram-sawp for RPI4 8G model.
repo --name="local-kernel"  --baseurl=http://local.repository.lan/nethserver/7/local/armhfp/  --cost=100
repo --name="centos-kernel" --baseurl=http://mirror.centos.org/altarch/7/kernel/armhfp/kernel-rpi2/    --cost=100

repo --name="nethserver-base"    --baseurl=http://packages.nethserver.org/nethserver/7.9.2009/base/armhfp/    --cost=100
repo --name="nethserver-updates" --baseurl=http://packages.nethserver.org/nethserver/7.9.2009/updates/armhfp/ --cost=100
# epel-pass1
repo --name="epel"               --baseurl=https://armv7.dev.centos.org/repodir/epel-pass-1/ --cost=100

# Disk setup
clearpart --initlabel --all
part /boot --fstype=vfat --size=768  --label=boot   --asprimary --ondisk img
part /     --fstype=ext4 --size=2560 --label=rootfs --asprimary --ondisk img

# Package setup
%packages --nocore
@centos-minimal
@nethserver-iso
nethserver-arm-epel
net-tools
cloud-utils-growpart
chrony
raspberrypi2-kernel4
raspberrypi2-firmware
raspberrypi-vc-utils
zram
%end


%pre
#End of Pre script for partitions
%end


%post
# Setting correct yum variable to use raspberrypi kernel repo
echo "Setting up kernel variant..."
echo "rpi2" > /etc/yum/vars/kvariant

# Disable / Mask kdump.service
echo "Masking kdump.service..."
systemctl mask kdump.service

# Specific cmdline.txt files needed for raspberrypi2/3
echo "Write cmdline.txt..."
cat > /boot/cmdline.txt << EOF
console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait
EOF

# On a PI we are pretty sure wireless network interface defaults to wlan0
# Configure wpa_supplicant to control wlan0
echo "Configuring wpa_supplicant..."
sed -i 's/INTERFACES=""/INTERFACES="-iwlan0"/' /etc/sysconfig/wpa_supplicant

# cpu_governor.service
echo "Applying cpu governor fix..."
cat > /etc/systemd/system/multi-user.target.wants/cpu_governor.service << EOF

# FIXME centos raspberrypi2-kernel(4) defaults to conservative governor,
# moreover the kernel-tools package is absent is the pi2-kernel repository.

[Unit]
Description=Set cpu governor to ondemand

[Service]
Type=oneshot
ExecStart=/bin/sh -c " for i in {0..3}; do echo ondemand > /sys/devices/system/cpu/cpu\$i/cpufreq/scaling_governor; done"

[Install]
WantedBy=multi-user.target
EOF

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


# Import rpm-gpg keys
echo "Importing rpm-gpg keys..."
rpm --import /etc/pki/rpm-gpg/*

%include ks/RPI-wifi.ks

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# Cleanup yum cache
yum clean all

%end
