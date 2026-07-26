# what hardware is actually in the box. linux only. on a plain VM most of
# this just reports qemu, so import it on bare metal and on the hosts with
# passthrough devices, where it tells you whether the guest really sees them
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dmidecode
    lm_sensors
    lshw
    pciutils # lspci
    usbutils # lsusb
  ];
}
