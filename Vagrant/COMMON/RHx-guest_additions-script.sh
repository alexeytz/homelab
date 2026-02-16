dnf groupinstall -y "Development Tools"
dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r) dkms

curl -o ./vbox.iso https://download.virtualbox.org/virtualbox/7.2.4/VBoxGuestAdditions_7.2.4.iso
mount -o loop ./vbox.iso /mnt
cd /mnt
./VBoxLinuxAdditions.run