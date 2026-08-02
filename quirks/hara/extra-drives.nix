{lib, ...}: let
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
in {
  fileSystems = drives;

  # these are noauto + automount, so systemd only mounts (and fscks) one on
  # first access. fsck.ntfs does a real full MFT scan every time regardless of
  # dirty state (10-50s+ on the bigger drives here), so whatever happens to
  # touch /mnt first eats that synchronously -- it used to be zsh validating
  # its directory-completion cache, but it could be anything. trigger all six
  # in parallel right after boot instead, so the checks run in the background
  # (bounded by the slowest single drive, not the sum of all of them) and are
  # long done before anyone opens a terminal.
  systemd.services.warm-mnt-automounts = {
    description = "trigger automount (and one-time fsck) for /mnt drives in the background instead of on first interactive access";
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target"];
    before = lib.mkForce [];
    serviceConfig.Type = "oneshot";
    script = ''
      ${lib.concatMapStringsSep "\n" (path: "stat ${lib.escapeShellArg path} >/dev/null 2>&1 &") (builtins.attrNames drives)}
      wait
    '';
  };
}
