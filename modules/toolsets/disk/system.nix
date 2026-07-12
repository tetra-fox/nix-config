# tools for poking at physical disks. import on hosts that see real
# hardware (store boxes with passthrough drives, bare-metal workstations)
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    smartmontools
    hdparm
    nvme-cli
    parted
  ];
}
