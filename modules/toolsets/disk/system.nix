# tools for poking at physical disks. import on hosts that see real
# hardware (store boxes with passthrough drives, bare-metal workstations)
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    duf
    # the only way to get real latency numbers off a pool rather than guessing from
    # throughput. 236M closure, most of it python for the plotting scripts
    fio
    gptfdisk # sgdisk, for reading partition tables disko wrote
    hdparm
    lsscsi
    nvme-cli
    parted
    smartmontools
  ];
}
