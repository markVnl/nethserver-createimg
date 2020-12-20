# Basic setup information
url --url="http://mirror.centos.org/altarch/7/os/aarch64/"
install
keyboard us --xlayouts=us --vckeymap=us
lang en_US.UTF-8
rootpw Nethesis,1234
timezone --isUtc --nontp UTC
selinux --disabled
firewall --disabled
network --bootproto=dhcp --device=link --activate --onboot=on
services --enabled=sshd,NetworkManager,chronyd,zram-swap,nethserver-system-init
skipx
shutdown
bootloader --location=none

# Repositories to use
repo --name="base"    --baseurl=http://mirror.centos.org/altarch/7/os/aarch64/      --cost=100
repo --name="updates" --baseurl=http://mirror.centos.org/altarch/7/updates/aarch64/ --cost=100
repo --name="extras"  --baseurl=http://mirror.centos.org/altarch/7/extras/aarch64/  --cost=100
repo --name="epel"    --baseurl=http://mirror.1000mbps.com/epel/7/aarch64/          --cost=100
repo --name="nethserver-base"    --baseurl=http://packages.nethserver.org/nethserver/7.7.1908/base/aarch64/    --cost=100
repo --name="nethserver-updates" --baseurl=http://packages.nethserver.org/nethserver/7.7.1908/updates/aarch64/ --cost=100
# Copr repo for epel-7-aarch64_SBC-tools owned by markvnl,
# this repo includes the kernel, uboot-images and aarch64-img-extra-config
repo --name="sbc-tools"   --baseurl=https://copr-be.cloud.fedoraproject.org/results/markvnl/epel-7-aarch64_SBC-tools/epel-7-$basearch/ --cost=100

# Package setup
%packages
@centos-minimal
@nethserver-iso
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
part /boot     --fstype=ext4 --size=768  --label=boot   --asprimary --ondisk img
part /         --fstype=ext4 --size=2560 --label=rootfs --asprimary --ondisk img

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

# (re)configure GRUB2, does not work (yet), 
# mounted the image on a loop device:
#   mount ${loopdev}p3 ${mountpoint}
#   mount ${loopdev}p2 ${mountpoint}/boot
#   mount ${loopdev}p1 ${mountpoint}/boot/efi
#   mount --bind /proc ${mountpoint}/proc
#   mount --bind /dev  ${mountpoint}/dev
#   mount --bind /sys  ${mountpoint}/sys
#
# and ran:
#   chroot ${mountpoint} /bin/bash -c "/usr/sbin/grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg"
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


## FIXME: end

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

echo "Write README file..."
cat >/root/README << EOF
== Nethserver el7.7.1908 development AARCH64 image ==

Note: this is a community effort not supported by centOS by any means
            
      Please check /root/anaconda-ks.cfg on how this image came to life

      nevertheless : have fun and debug!  


(as usual) If you want to automatically resize your / partition to use the full sd-card, 
just type the following:

rootfs-expand

EOF


# Enable heartbeat LED
echo "ledtrig-heartbeat" > /etc/modules-load.d/sbc.conf

echo "Disabeling and Masking kdump.service..."
systemctl mask kdump.service


echo "Setting up Raspbery PI 3(+) wlan firmware..."
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


# RaspberryPI 3 model+ wlan config
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
