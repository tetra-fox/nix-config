# zfs as a filesystem type. this also puts zpool/zfs in PATH, version-locked
# to the kernel module, which is why they're not in the disk toolset
{
  config,
  lib,
  pkgs,
  ...
}: {
  boot.supportedFilesystems = ["zfs"];

  # zfs needs a compatible kernel. pin it to the latest LTS
  # TODO: bump when we get a new `longterm`: https://kernel.org/
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  # zfs refuses to import a pool last touched by a different hostid; derive a
  # stable unique one from the hostname instead of hand-picking hex per host
  networking.hostId = lib.mkDefault (builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName));

  services.zfs = {
    # weekly default is a lot of thrash on multi-TB spinning pools
    autoScrub = {
      enable = true;
      interval = "monthly";
    };

    # only snapshots datasets with com.sun:auto-snapshot=true set, so this is
    # opt-in per dataset, not a blanket snapshot of the whole pool. frequent
    # off: 15-minute snapshots are churn we don't want on a media store
    autoSnapshot = {
      enable = true;
      frequent = 0;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
  };
}
