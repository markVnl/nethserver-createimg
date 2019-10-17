
# Basic setup information
install
keyboard us --xlayouts=us --vckeymap=us
rootpw Nethesis,1234
timezone --isUtc --nontp UTC
selinux --disabled
firewall --disabled
#On a raspbery Pi we are pretty sure network defaults to eth0
network --device=eth0 --activate --bootproto=dhcp --onboot=on --noipv6 --hostname=localhost.localdomain
services --enabled=sshd,network,chronyd,zram-swap,nethserver-system-init
shutdown
lang en_US.UTF-8

# Repositories to use
repo --name="base"          --baseurl=http://mirror.centos.org/altarch/7/os/armhfp/      --cost=100
repo --name="updates"       --baseurl=http://mirror.centos.org/altarch/7/updates/armhfp/ --cost=100
repo --name="extras"        --baseurl=http://mirror.centos.org/altarch/7/extras/armhfp/  --cost=100
repo --name="centos-kernel" --baseurl=http://mirror.centos.org/altarch/7/kernel/armhfp/kernel-rpi2/    --cost=100
repo --name="nethserver-base"    --baseurl=http://packages.nethserver.org/nethserver/7.7.1908/base/armhfp/    --cost=100
repo --name="nethserver-updates" --baseurl=http://packages.nethserver.org/nethserver/7.7.1908/updates/armhfp/ --cost=100
# epel-pass1
repo --name="epel"               --baseurl=https://armv7.dev.centos.org/repodir/epel-pass-1/ --cost=100
# test
repo --name="local"  --baseurl=http://local.repository.lan/nethserver/7.7.1908/local/armhfp --cost=100

# Disk setup
clearpart --initlabel --all
part /boot --fstype=vfat --size=768  --label=boot   --asprimary --ondisk img
part /     --fstype=ext4 --size=2560 --label=rootfs --asprimary --ondisk img

# Package setup
%packages
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
# FIXME: why are we doing this?
#        initramfs seem to be completly ignored..
# Generating initrd
echo "Generating initrd...."
export kvr=$(rpm -q --queryformat '%{version}-%{release}' $(rpm -q raspberrypi2-kernel4|tail -n 1))
dracut --force /boot/initramfs-$kvr.armv7hl.img $kvr.armv7hl

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


echo "Setting up Raspbery PI 3(+)/4 wlan firmware..."
# RaspberryPi 3 wlan config
# source (short_commit 130cb86):
# https://github.com/RPi-Distro/firmware-nonfree/blob/master/brcm/brcmfmac43430-sdio.raspberrypi-rpi.txt
cat > /usr/lib/firmware/brcm/brcmfmac43430-sdio.txt << EOF
# SPDX-License-Identifier: GPL-2.0+
# (C) Copyright 2018 Raspberry Pi (Trading) Ltd.
# NVRAM config file for the BCM43430 WiFi/BT chip as found on the
# Raspberry Pi 3 Model B
aa2g=1
ag0=255
AvVmid_c0=0x0,0xc8
boardflags=0x00404201
boardflags3=0x08000000
boardnum=22
boardrev=0x1202
boardtype=0x0726
btc_mode=1
btc_params1=0x7530
btc_params8=0x4e20
cckbw202gpo=0
cckpwroffset0=5
ccode=ALL
# cldo_pwm is not set
deadman_to=0xffffffff
devid=0x43e2
extpagain2g=0
il0macaddr=00:90:4c:c5:12:38
legofdmbw202gpo=0x66111111
macaddr=00:90:4c:c5:12:38
manfid=0x2d0
maxp2ga0=84
mcsbw202gpo=0x77711111
muxenab=0x1
nocrc=1
ofdmdigfilttype=18
ofdmdigfilttypebe=18
pa0itssit=0x20
pa2ga0=-168,7161,-820
pacalidx2g=32
papdendidx=61
papdepsoffset=-36
papdmode=1
papdvalidtest=1
prodid=0x0726
propbw202gpo=0xdd
spurconfig=0x3 
sromrev=11
txpwrbckof=6
vendid=0x14e4
wl0id=0x431b
xtalfreq=37400

EOF


# RaspberryPI 3 model+ & RaspberryPI 4 wlan config
# source (short_commit 130cb86):
# https://github.com/RPi-Distro/firmware-nonfree/blob/master/brcm/brcmfmac43455-sdio.txt
cat > /usr/lib/firmware/brcm/brcmfmac43455-sdio.txt << EOF
# Cloned from bcm94345wlpagb_p2xx.txt 
NVRAMRev=$Rev: 498373 $
sromrev=11
vendid=0x14e4
devid=0x43ab
manfid=0x2d0
prodid=0x06e4
#macaddr=00:90:4c:c5:12:38
macaddr=b8:27:eb:74:f2:6c
nocrc=1
boardtype=0x6e4
boardrev=0x1304

#XTAL 37.4MHz
xtalfreq=37400

btc_mode=1
#------------------------------------------------------
#boardflags: 5GHz eTR switch by default
#            2.4GHz eTR switch by default
#            bit1 for btcoex
boardflags=0x00480201
boardflags2=0x40800000
boardflags3=0x44200100
phycal_tempdelta=15
rxchain=1
txchain=1
aa2g=1
aa5g=1
tssipos5g=1
tssipos2g=1
femctrl=0
AvVmid_c0=1,165,2,100,2,100,2,100,2,100
pa2ga0=-129,6525,-718
pa2ga1=-149,4408,-601
pa5ga0=-185,6836,-815,-186,6838,-815,-184,6859,-815,-184,6882,-818
pa5ga1=-202,4285,-574,-201,4312,-578,-196,4391,-586,-201,4294,-575
itrsw=1
pdoffsetcckma0=2
pdoffset2gperchan=0,-2,1,0,1,0,1,1,1,0,0,-1,-1,0
pdoffset2g40ma0=16
pdoffset40ma0=0x8888
pdoffset80ma0=0x8888
extpagain5g=2
extpagain2g=2
tworangetssi2g=1
tworangetssi5g=1
# LTECX flags
# WCI2
ltecxmux=0
ltecxpadnum=0x0504
ltecxfnsel=0x22
ltecxgcigpio=0x32

maxp2ga0=80
ofdmlrbw202gpo=0x0022
dot11agofdmhrbw202gpo=0x4442
mcsbw202gpo=0x98444422
mcsbw402gpo=0x98444422
maxp5ga0=82,82,82,82
mcsbw205glpo=0xb9555000
mcsbw205gmpo=0xb9555000
mcsbw205ghpo=0xb9555000
mcsbw405glpo=0xb9555000
mcsbw405gmpo=0xb9555000
mcsbw405ghpo=0xb9555000
mcsbw805glpo=0xb9555000
mcsbw805gmpo=0xb9555000
mcsbw805ghpo=0xb9555000

swctrlmap_2g=0x00000000,0x00000000,0x00000000,0x010000,0x3ff
swctrlmap_5g=0x00100010,0x00200020,0x00200020,0x010000,0x3fe
swctrlmapext_5g=0x00000000,0x00000000,0x00000000,0x000000,0x3
swctrlmapext_2g=0x00000000,0x00000000,0x00000000,0x000000,0x3

vcodivmode=1
deadman_to=481500000

ed_thresh2g=-54
ed_thresh5g=-54
eu_edthresh2g=-54
eu_edthresh5g=-54
ldo1=4
rawtempsense=0x1ff
cckPwrIdxCorr=3
cckTssiDelay=150
ofdmTssiDelay=150
txpwr2gAdcScale=1
txpwr5gAdcScale=1
dot11b_opts=0x3aa85
cbfilttype=1
fdsslevel_ch11=6

# Improved Bluetooth coexistence parameters from Cypress
btc_mode=1
btc_params8=0x4e20
btc_params1=0x7530

EOF

# Remove ifcfg-link on pre generated images
rm -f /etc/sysconfig/network-scripts/ifcfg-link

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# Cleanup yum cache
yum clean all

%end
