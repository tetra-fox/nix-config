# import on hosts that see real disks
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    duf
    fio # 236M closure, mostly python for plotting
    gptfdisk
    hdparm
    lsscsi
    nvme-cli
    parted
    smartmontools
  ];
}
