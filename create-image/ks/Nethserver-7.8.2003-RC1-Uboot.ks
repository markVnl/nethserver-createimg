# Basic setup information
install
keyboard us --xlayouts=us --vckeymap=us
rootpw Nethesis,1234
timezone --isUtc --nontp UTC
selinux --disabled
firewall --disabled
#On armhfp we are pretty sure network defaults to eth0
network --device=eth0 --activate --bootproto=dhcp --onboot=on --noipv6 --hostname=localhost.localdomain
services --enabled=sshd,NetworkManager,chronyd,zram-swap,nethserver-system-init
shutdown
bootloader --location=mbr
lang en_US.UTF-8

# Repositories to use
repo --name="base"          --baseurl=http://mirror.centos.org/altarch/7/os/armhfp/      --cost=100
repo --name="updates"       --baseurl=http://mirror.centos.org/altarch/7/updates/armhfp/ --cost=100
repo --name="extras"        --baseurl=http://mirror.centos.org/altarch/7/extras/armhfp/  --cost=100
repo --name="centos-kernel" --baseurl=http://mirror.centos.org/altarch/7/kernel/armhfp/kernel-generic/  --cost=100
repo --name="nethserver-base"    --baseurl=http://packages.nethserver.org/nethserver/7.7.1908/base/armhfp/    --cost=100
repo --name="nethserver-updates" --baseurl=http://packages.nethserver.org/nethserver/7.7.1908/updates/armhfp/ --cost=100
# epel-pass1
repo --name="epel"               --baseurl=https://armv7.dev.centos.org/repodir/epel-pass-1/ --cost=100


# Disk setup
clearpart --initlabel --all
part /boot --fstype=ext4 --size=768  --label=boot   --asprimary --ondisk img
part /     --fstype=ext4 --size=2560 --label=rootfs --asprimary --ondisk img

# Package setup
%packages
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

# Wireless tweaks

# For cubietruck WiFi : kernel module works and linux-firmware has the needed file
# But it just needs a .txt config file 

cat > /lib/firmware/brcm/brcmfmac43362-sdio.txt << EOF

AP6210_NVRAM_V1.2_03192013
manfid=0x2d0
prodid=0x492
vendid=0x14e4
devid=0x4343
boardtype=0x0598

# Board Revision is P307, same nvram file can be used for P304, P305, P306 and P307 as the tssi pa params used are same
#Please force the automatic RX PER data to the respective board directory if not using P307 board, for e.g. for P305 boards force the data into the following directory /projects/BCM43362/a1_labdata/boardtests/results/sdg_rev0305
boardrev=0x1307
boardnum=777
xtalfreq=26000
boardflags=0x80201
boardflags2=0x80
sromrev=3
wl0id=0x431b
macaddr=00:90:4c:07:71:12
aa2g=1
ag0=2
maxp2ga0=74
cck2gpo=0x2222
ofdm2gpo=0x44444444
mcs2gpo0=0x6666
mcs2gpo1=0x6666
pa0maxpwr=56

#P207 PA params
#pa0b0=5447
#pa0b1=-658
#pa0b2=-175<div></div>

#Same PA params for P304,P305, P306, P307

pa0b0=5447
pa0b1=-607
pa0b2=-160
pa0itssit=62
pa1itssit=62


cckPwrOffset=5
ccode=0
rssismf2g=0xa
rssismc2g=0x3
rssisav2g=0x7
triso2g=0
noise_cal_enable_2g=0
noise_cal_po_2g=0
swctrlmap_2g=0x04040404,0x02020202,0x02020202,0x010101,0x1ff
temp_add=29767
temp_mult=425

btc_flags=0x6
btc_params0=5000
btc_params1=1000
btc_params6=63

EOF

# Remove ifcfg-link on pre generated images
rm -f /etc/sysconfig/network-scripts/ifcfg-link

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# Cleanup yum cache
yum clean all

%end
