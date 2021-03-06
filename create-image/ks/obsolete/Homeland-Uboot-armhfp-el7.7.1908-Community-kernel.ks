# Basic setup information
url --url="http://mirror.centos.org/altarch/7/os/armhfp/"
install
keyboard us --xlayouts=us --vckeymap=us
lang en_US.UTF-8
rootpw centos
timezone --isUtc --nontp UTC
selinux --permissive
firewall --enabled --port=22
network --bootproto=dhcp --device=link --activate --onboot=on
services --enabled=sshd,NetworkManager,chronyd,zram-swap
shutdown
bootloader --location=mbr

# Repositories to use
repo --name="base"     --baseurl=http://mirror.centos.org/altarch/7/os/armhfp/      --cost=100
repo --name="updates"  --baseurl=http://mirror.centos.org/altarch/7/updates/armhfp/ --cost=100
repo --name="extras"   --baseurl=http://mirror.centos.org/altarch/7/extras/armhfp/  --cost=100
repo --name="kernel"   --baseurl=https://armv7.dev.centos.org/repodir/community-kernel-latest/ --cost=100
# Copr repo for epel-7-aarch64_SBC-tools owned by markvnl for zram.
# zram is a noarch package living in an aarch64-repo (copr does not have an armhfp build target)
repo --name="sbc-tools" --baseurl=https://copr-be.cloud.fedoraproject.org/results/markvnl/epel-7-aarch64_SBC-tools/epel-7-aarch64/ --cost=100

# Package setup
%packages
@core
grubby
net-tools
cloud-utils-growpart
chrony
kernel
dracut-config-generic
-dracut-config-rescue
extlinux-bootloader
uboot-images-armv7
zram
%end

# Disk setup
clearpart --initlabel --all
part /boot --fstype=ext4 --size=768  --label=rootfs --asprimary --ondisk img
part /     --fstype=ext4 --size=2560 --label=rootfs --asprimary --ondisk img

%pre
#End of Pre script for partitions
%end


%post

# Setting correct yum variable to use mainline kernel repo
echo "Setting up kernel variant..."
echo "generic" > /etc/yum/vars/kvariant

# Disable / Mask kdump.service
echo "Masking kdump.service..."
systemctl mask kdump.service

# Add (default disabled) community-kernel-latest repository
echo "Adding community-kernel-latest repository..."
cat >> /etc/yum.repos.d/CentOS-armhfp-kernel.repo << EOF

[community-kernel]
name=Community Kernels for armhfp
baseurl=https://armv7.dev.centos.org/repodir/community-kernel-latest/
enabled=0
gpgcheck=0

EOF

# Mandatory README file
echo "Write README file..."
cat >/root/README << EOF
== Homeland el7 ==

If you want to automatically resize your / partition, just type the following (as root user):
rootfs-expand

EOF

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
