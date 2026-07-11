_: let
  baseOptions = [
    "noauto"
    "nofail"
    "noatime"
    "x-systemd.automount"
    "uid=1000"
    "gid=100"
    "umask=0022"
    "nocase"
  ];
  roOptions =
    baseOptions
    ++ [
      "ro"
      # "x-systemd.idle-timeout=60"
    ];
  rwOptions =
    baseOptions
    ++ [
      "rw"
      "windows_names"
      # "x-systemd.idle-timeout=0"
    ];
in {
  # declaring fsType = "ntfs" mounts makes nixos add pkgs.ntfs3g to system.fsPackages
  # (nixos/modules/tasks/filesystems/ntfs.nix). that package ships /sbin/mount.ntfs,
  # which the mount syscall path picks up as a helper and which mounts via FUSE
  # (fuseblk) instead of the in-kernel ntfs driver we want. there is no nixos option
  # to opt out, so disable that stock module; the kernel module autoloads by fstype.
  disabledModules = ["tasks/filesystems/ntfs.nix"];

  fileSystems = {
    "/mnt/data" = {
      device = "/dev/disk/by-uuid/601C0E101C0DE1C0";
      fsType = "ntfs";
      options = roOptions;
    };

    "/mnt/games" = {
      device = "/dev/disk/by-uuid/56424FA6424F8A27";
      fsType = "ntfs";
      options = rwOptions;
    };

    "/mnt/music" = {
      device = "/dev/disk/by-uuid/DECAF453CAF42A03";
      fsType = "ntfs";
      options = roOptions;
    };

    "/mnt/wd-black" = {
      device = "/dev/disk/by-uuid/10AAA832AAA8166E";
      fsType = "ntfs";
      options = rwOptions;
    };

    "/mnt/vault" = {
      device = "/dev/disk/by-uuid/D6A03453A0343BF5";
      fsType = "ntfs";
      options = rwOptions;
    };

    "/mnt/windows" = {
      device = "/dev/disk/by-uuid/E2AAEB4BAAEB1AB5";
      fsType = "ntfs";
      options = roOptions;
    };
  };
}
