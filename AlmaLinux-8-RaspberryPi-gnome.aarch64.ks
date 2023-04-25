# To build an image run the following as root:
# appliance-creator -c AlmaLinux-8-RaspberryPi-gnome.aarch64.ks \
#   -d -v --logfile /var/tmp/AlmaLinux-8-RaspberryPi-gnome-$(date +%Y%m%d-%s).aarch64.ks.log \
#   --cache /root/cache --no-compress \
#   -o $(pwd) --format raw --name AlmaLinux-8-RaspberryPi-gnome-$(date +%Y%m%d-%s).aarch64 | \
#   tee /var/tmp/AlmaLinux-8-RaspberryPi-latest-$(date +%Y%m%d-%s).aarch64.ks.log.2
# Basic setup information
url --url="https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/os/"
rootpw --plaintext almalinux

# Repositories to use
repo --name="baseos" --baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/os/
repo --name="appstream" --baseurl=https://repo.almalinux.org/almalinux/8/AppStream/aarch64/os/
repo --name="raspberrypi" --baseurl=https://repo.almalinux.org/almalinux/8/raspberrypi/aarch64/os/

# install
keyboard us --xlayouts=us --vckeymap=us
timezone --isUtc --nontp UTC
selinux --enforcing
firewall --enabled --port=22:tcp
network --bootproto=dhcp --device=link --activate --onboot=on
services --enabled=sshd,NetworkManager,chronyd
shutdown
bootloader --location=mbr
lang en_US.UTF-8

# Disk setup
clearpart --initlabel --all
part /boot --asprimary --fstype=vfat --size=500 --label=boot
part / --asprimary --fstype=ext4 --size=4400 --label=rootfs

# Package setup
%packages
@core
@gnome-desktop
firefox
dejavu-sans-fonts
dejavu-sans-mono-fonts
dejavu-serif-fonts
aajohan-comfortaa-fonts
abattis-cantarell-fonts
-caribou*
-gnome-shell-browser-plugin
-java-1.6.0-*
-java-1.7.0-*
-java-11-*
-python*-caribou*
NetworkManager-wifi
almalinux-release-raspberrypi
chrony
cloud-utils-growpart
e2fsprogs
net-tools
linux-firmware-raspberrypi
raspberrypi2-firmware
raspberrypi2-kernel4
nano
%end

%post
# Mandatory README file
cat >/root/README << EOF
== AlmaLinux 8 ==

If you want to automatically resize your / partition, just type the following (as root user):
rootfs-expand

EOF

# root password change motd
cat >/etc/motd << EOF
It's highly recommended to change root password by typing the following:
passwd

To remove this message:
>/etc/motd

EOF

cat > /boot/config.txt << EOF
# This file is provided as a placeholder for user options
# AlmaLinux - few default config options for better graphics support
[all]
disable_overscan=1
dtoverlay=vc4-kms-v3d
camera_auto_detect=0
gpu_mem=64

## AlmaLinux - can enable this for Pi 4 and later
#[pi4]
#max_framebuffers=2
EOF

# Specific cmdline.txt files needed for raspberrypi2/3
cat > /boot/cmdline.txt << EOF
console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait
EOF

# Create and initialize swapfile
(umask 077; dd if=/dev/zero of=/swapfile bs=1M count=100)
/usr/sbin/mkswap -p 4096 -L "_swap" /swapfile
cat >> /etc/fstab << EOF
/swapfile	none	swap	defaults	0	0
EOF

# Remove ifcfg-link on pre generated images
rm -f /etc/sysconfig/network-scripts/ifcfg-link

# rebuild dnf cache
dnf clean all
/bin/date +%Y%m%d_%H%M > /etc/BUILDTIME
echo '%_install_langs C.utf8' > /etc/rpm/macros.image-language-conf
echo 'LANG="C.utf8"' >  /etc/locale.conf
rpm --rebuilddb
# activate gui
systemct set-default graphical.target

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id
# print disk usage
df
#
%end

%post --nochroot --erroronfail

/usr/sbin/blkid
LOOPPART=$(cat /proc/self/mounts |/usr/bin/grep '^\/dev\/mapper\/loop[0-9]p[0-9] '"$INSTALL_ROOT " | /usr/bin/sed 's/ .*//g')
echo "Found loop part for PARTUUID $LOOPPART"
BOOTDEV=$(/usr/sbin/blkid $LOOPPART|grep 'PARTUUID="........-02"'|sed 's/.*PARTUUID/PARTUUID/g;s/ .*//g;s/"//g')
echo "no chroot selected bootdev=$BOOTDEV"
if [ -n "$BOOTDEV" ];then
    cat $INSTALL_ROOT/boot/cmdline.txt
    echo sed -i "s|root=/dev/mmcblk0p2|root=${BOOTDEV}|g" $INSTALL_ROOT/boot/cmdline.txt
    sed -i "s|root=/dev/mmcblk0p2|root=${BOOTDEV}|g" $INSTALL_ROOT/boot/cmdline.txt
fi
cat $INSTALL_ROOT/boot/cmdline.txt

%end
