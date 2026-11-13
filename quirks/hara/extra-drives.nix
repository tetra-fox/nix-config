{lib, ...}: let
  mountOptions = [
    "noauto"
    "nofail"
    "noatime"
    "x-systemd.automount"
  ];
  ntfsOptions =
    mountOptions
    ++ [
      "uid=1000"
      "gid=100"
      "umask=0022"
      "nocase"
    ];
  roOptions =
    ntfsOptions
    ++ [
      "ro"
    ];
  rwOptions =
    ntfsOptions
    ++ [
      "rw"
      "windows_names"
    ];

  drives = {
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
      options = rwOptions;
    };

    "/mnt/wd-black" = {
      device = "/dev/disk/by-uuid/ff07fc22-f7ee-4f5e-a8d2-f45613fbd709";
      fsType = "btrfs";
      # spinning disk, so compression saves more io time than it costs in cpu
      # and autodefrag keeps cow rewrites from scattering files across the platter
      options =
        mountOptions
        ++ [
          "compress=zstd"
          "autodefrag"
        ];
    };

    "/home/tetra/Documents/git" = {
      device = "/mnt/wd-black/git";
      fsType = "none";
      # nofail so a missing disk or source dir does not fail local-fs.target
      options = [
        "bind"
        "nofail"
        "x-systemd.requires-mounts-for=/mnt/wd-black"
      ];
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
in {
  fileSystems = lib.mapAttrs (_: drive: drive // {noCheck = true;}) drives;

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = ["/mnt/wd-black"];
  };
}
