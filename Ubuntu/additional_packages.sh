apt install -y qemu-guest-agent lrzsz tree

# lrzsz - package providing tools (lrz and lsz) to transfer files over serial ports or terminal
#         emulators using error-correcting protocols like ZMODEM, XMODEM, and YMODEM. Used by WindTerm.

systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent